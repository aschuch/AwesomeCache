import Foundation

/// Represents the expiry of a cached object
public enum CacheExpiry {
    case never
    case seconds(TimeInterval)
    case date(Foundation.Date)
}

/// A generic cache that persists objects to disk and is backed by a NSCache.
/// Supports an expiry date for every cached object. Expired objects are automatically deleted upon their next access via `objectForKey:`.
/// If you want to delete expired objects, call `removeAllExpiredObjects`.
///
/// Subclassing notes: This class fully supports subclassing.
/// The easiest way to implement a subclass is to override `objectForKey` and `setObject:forKey:expires:`,
/// e.g. to modify values prior to reading/writing to the cache.
open class Cache<T: NSCoding> {
    open let name: String
    open let cacheDirectory: URL

    internal let cache = NSCache<NSString, CacheObject>() // marked internal for testing
    fileprivate let fileManager = FileManager()
    fileprivate let queue = DispatchQueue(label: "com.aschuch.cache.diskQueue", attributes: DispatchQueue.Attributes.concurrent)

    /// Typealias to define the reusability in declaration of the closures.
    public typealias CacheBlockClosure = (T, CacheExpiry) -> Void
    public typealias ErrorClosure = (NSError?) -> Void


    // MARK: Initializers

    /// Designated initializer.
    ///
    /// - parameter name: Name of this cache
    ///	- parameter directory:  Objects in this cache are persisted to this directory.
    ///                         If no directory is specified, a new directory is created in the system's Caches directory
    /// - parameter fileProtection: Needs to be a valid value for `NSFileProtectionKey` (i.e. `NSFileProtectionNone`) and 
    ///                             adds the given value as an NSFileManager attribute.
    ///
    ///  - returns:	A new cache with the given name and directory
    public init(name: String, directory: URL?, fileProtection: String? = nil) throws {
        self.name = name
        cache.name = name

        if let d = directory {
            cacheDirectory = d
        } else {
            let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            cacheDirectory = url.appendingPathComponent("com.aschuch.cache/\(name)")
        }

        // Create directory on disk if needed
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)

        if let fileProtection = fileProtection {
            // Set the correct NSFileProtectionKey
            let protection = [FileAttributeKey.protectionKey: fileProtection]
            try fileManager.setAttributes(protection, ofItemAtPath: cacheDirectory.path)
        }
    }

    /// Convenience Initializer
    ///
    /// - parameter name: Name of this cache
    ///
    /// - returns	A new cache with the given name and the default cache directory
    public convenience init(name: String) throws {
        try self.init(name: name, directory: nil)
    }


    // MARK: Awesome caching

    /// Returns a cached object immediately or evaluates a cacheBlock.
    /// The cacheBlock will not be re-evaluated until the object is expired or manually deleted.
    /// If the cache already contains an object, the completion block is called with the cached object immediately.
    ///
    /// If no object is found or the cached object is already expired, the `cacheBlock` is called.
    /// You might perform any tasks (e.g. network calls) within this block. Upon completion of these tasks,
    /// make sure to call the `success` or `failure` block that is passed to the `cacheBlock`.
    /// The completion block is invoked as soon as the cacheBlock is finished and the object is cached.
    ///
    /// - parameter key:			The key to lookup the cached object
    /// - parameter cacheBlock:	This block gets called if there is no cached object or the cached object is already expired.
    ///                         The supplied success or failure blocks must be called upon completion.
    ///                         If the error block is called, the object is not cached and the completion block is invoked with this error.
    /// - parameter completion: Called as soon as a cached object is available to use. The second parameter is true if the object was already cached.
    open func setObject(forKey key: String, cacheBlock: (CacheBlockClosure, ErrorClosure) -> Void, completion: @escaping (T?, Bool, NSError?) -> Void) {
        if let object = object(forKey: key) {
            completion(object, true, nil)
        } else {
            let successBlock: CacheBlockClosure = { (obj, expires) in
                self.setObject(obj, forKey: key, expires: expires)
                completion(obj, false, nil)
            }

            let failureBlock: ErrorClosure = { (error) in
                completion(nil, false, error)
            }

            cacheBlock(successBlock, failureBlock)
        }
    }


    // MARK: Get object

    /// Looks up and returns an object with the specified name if it exists.
    /// If an object is already expired, `nil` will be returned.
    ///
    /// - parameter key: The name of the object that should be returned
    /// - parameter returnExpiredObjectIfPresent: If set to `true`, an expired 
    ///             object may be returned if present. Defaults to `false`.
    ///
    /// - returns: The cached object for the given name, or nil
    open func object(forKey key: String, returnExpiredObjectIfPresent: Bool = false) -> T? {
        var object: CacheObject?

        queue.sync {
            object = self.read(key)
        }

        // Check if object is not already expired and return
        if let object = object, !object.isExpired() || returnExpiredObjectIfPresent {
            return object.value as? T
        }

        return nil
    }

    open func allObjects(includeExpired: Bool = false) -> [T] {
        var objects = [T]()

        queue.sync {
            let keys = self.allKeys()
            let all = keys.map(self.read).flatMap { $0 }
            let filtered = includeExpired ? all : all.filter { !$0.isExpired() }
            objects = filtered.map { $0.value as? T }.flatMap { $0 }
        }

        return objects
    }

    open func isOnMemory(forKey key: String) -> Bool {
        return cache.object(forKey: key as NSString) != nil
    }


    // MARK: Set object

    /// Adds a given object to the cache.
    /// The object is automatically marked as expired as soon as its expiry date is reached.
    ///
    /// - parameter object:	The object that should be cached
    /// - parameter forKey:	A key that represents this object in the cache
    /// - parameter expires: The CacheExpiry that indicates when the given object should be expired
    open func setObject(_ object: T, forKey key: String, expires: CacheExpiry = .never) {
        let expiryDate = expiryDateForCacheExpiry(expires)
        let cacheObject = CacheObject(value: object, expiryDate: expiryDate)

        queue.sync(flags: .barrier, execute: {
            self.add(cacheObject, key: key)
        }) 
    }

    // MARK: Remove objects

    /// Removes an object from the cache.
    ///
    /// - parameter key: The key of the object that should be removed
    open func removeObject(forKey key: String) {
        cache.removeObject(forKey: key as NSString)

        queue.sync(flags: .barrier, execute: {
            self.removeFromDisk(key)
        }) 
    }

    /// Removes all objects from the cache.
    open func removeAllObjects() {
        cache.removeAllObjects()
        
        queue.sync(flags: .barrier, execute: {
            let keys = self.allKeys()
            keys.forEach(self.removeFromDisk)
        }) 
    }

    /// Removes all expired objects from the cache.
    open func removeExpiredObjects() {
        queue.sync(flags: .barrier, execute: {
            let keys = self.allKeys()

            for key in keys {
                let possibleObject = self.read(key)
                if let object = possibleObject , object.isExpired() {
                    self.cache.removeObject(forKey: key as NSString)
                    self.removeFromDisk(key)
                }
            }
        }) 
    }

    // MARK: Subscripting

    open subscript(key: String) -> T? {
        get {
            return object(forKey: key)
        }
        set(newValue) {
            if let value = newValue {
                setObject(value, forKey: key)
            } else {
                removeObject(forKey: key)
            }
        }
    }

    // MARK: Private Helper (not thread safe)

    fileprivate func add(_ object: CacheObject, key: String) {
        // Set object in local cache
        cache.setObject(object, forKey: key as NSString)

        // Write object to disk
        let path = urlForKey(key).path
        NSKeyedArchiver.archiveRootObject(object, toFile: path)
    }

    fileprivate func read(_ key: String) -> CacheObject? {
        // Check if object exists in local cache
        if let object = cache.object(forKey: key as NSString) {
            return object
        }

        // Otherwise, read from disk
        let path = urlForKey(key).path
        if fileManager.fileExists(atPath: path) {
            return _awesomeCache_unarchiveObjectSafely(path) as? CacheObject
        }

        return nil
    }

    // Deletes an object from disk
    fileprivate func removeFromDisk(_ key: String) {
        let url = self.urlForKey(key)
        _ = try? self.fileManager.removeItem(at: url)
    }


    // MARK: Private Helper

    fileprivate func allKeys() -> [String] {
        let urls = try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil, options: [])
        return urls?.flatMap { $0.deletingPathExtension().lastPathComponent } ?? []
    }

    fileprivate func urlForKey(_ key: String) -> URL {
        let k = sanitizedKey(key)
        return cacheDirectory
            .appendingPathComponent(k)
            .appendingPathExtension("cache")
    }

    fileprivate func sanitizedKey(_ key: String) -> String {
        return key.replacingOccurrences(of: "[^a-zA-Z0-9_]+", with: "-", options: .regularExpression, range: nil)
    }

    fileprivate func expiryDateForCacheExpiry(_ expiry: CacheExpiry) -> Date {
        switch expiry {
        case .never:
            return Date.distantFuture
        case .seconds(let seconds):
            return Date().addingTimeInterval(seconds)
        case .date(let date):
            return date
        }
    }
}
