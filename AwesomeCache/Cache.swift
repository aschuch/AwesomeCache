import Foundation

/// Represents the expiry of a cached object
public enum CacheExpiry {
    case Never
    case Seconds(NSTimeInterval)
    case Date(NSDate)
}

/// A generic cache that persists objects to disk and is backed by a NSCache.
/// Supports an expiry date for every cached object. Expired objects are automatically deleted upon their next access via `objectForKey:`.
/// If you want to delete expired objects, call `removeAllExpiredObjects`.
///
/// Subclassing notes: This class fully supports subclassing.
/// The easiest way to implement a subclass is to override `objectForKey` and `setObject:forKey:expires:`,
/// e.g. to modify values prior to reading/writing to the cache.
public class Cache<T: NSCoding> {
    public let name: String
    public let cacheDirectory: NSURL

    internal let cache = NSCache() // marked internal for testing
    private let fileManager = NSFileManager()
    private let queue = dispatch_queue_create("com.aschuch.cache.diskQueue", DISPATCH_QUEUE_CONCURRENT)

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
    public init(name: String, directory: NSURL?, fileProtection: String? = nil) throws {
        self.name = name
        cache.name = name

        if let d = directory {
            cacheDirectory = d
        } else {
            let url = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).first!
            cacheDirectory = url.URLByAppendingPathComponent("com.aschuch.cache/\(name)")!
        }

        // Create directory on disk if needed
        try fileManager.createDirectoryAtURL(cacheDirectory, withIntermediateDirectories: true, attributes: nil)

        if let fileProtection = fileProtection {
            // Set the correct NSFileProtectionKey
            let protection = [NSFileProtectionKey: fileProtection]
            try fileManager.setAttributes(protection, ofItemAtPath: cacheDirectory.path!)
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
    public func setObjectForKey(key: String, cacheBlock: (CacheBlockClosure, ErrorClosure) -> Void, completion: (T?, Bool, NSError?) -> Void) {
        if let object = objectForKey(key) {
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
    public func objectForKey(key: String, returnExpiredObjectIfPresent: Bool = false) -> T? {
        var object: CacheObject?

        dispatch_sync(queue) {
            object = self.read(key)
        }

        // Check if object is not already expired and return
        if let object = object where !object.isExpired() || returnExpiredObjectIfPresent {
            return object.value as? T
        }

        return nil
    }

    public func allObjects(includeExpired includeExpired: Bool = false) -> [T] {
        var objects = [T]()

        dispatch_sync(queue) {
            let keys = self.allKeys()
            let all = keys.map(self.read).flatMap { $0 }
            let filtered = includeExpired ? all : all.filter { !$0.isExpired() }
            objects = filtered.map { $0.value as? T }.flatMap { $0 }
        }

        return objects
    }


    // MARK: Set object

    /// Adds a given object to the cache.
    /// The object is automatically marked as expired as soon as its expiry date is reached.
    ///
    /// - parameter object:	The object that should be cached
    /// - parameter forKey:	A key that represents this object in the cache
    /// - parameter expires: The CacheExpiry that indicates when the given object should be expired
    public func setObject(object: T, forKey key: String, expires: CacheExpiry = .Never) {
        let expiryDate = expiryDateForCacheExpiry(expires)
        let cacheObject = CacheObject(value: object, expiryDate: expiryDate)

        dispatch_barrier_sync(queue) {
            self.add(cacheObject, key: key)
        }
    }

    // MARK: Remove objects

    /// Removes an object from the cache.
    ///
    /// - parameter key: The key of the object that should be removed
    public func removeObjectForKey(key: String) {
        cache.removeObjectForKey(key)

        dispatch_barrier_sync(queue) {
            self.removeFromDisk(key)
        }
    }

    /// Removes all objects from the cache.
    public func removeAllObjects() {
        cache.removeAllObjects()
        
        dispatch_barrier_sync(queue) {
            let keys = self.allKeys()
            keys.forEach(self.removeFromDisk)
        }
    }

    /// Removes all expired objects from the cache.
    public func removeExpiredObjects() {
        dispatch_barrier_sync(queue) {
            let keys = self.allKeys()

            for key in keys {
                let possibleObject = self.read(key)
                if let object = possibleObject where object.isExpired() {
                    self.cache.removeObjectForKey(key)
                    self.removeFromDisk(key)
                }
            }
        }
    }

    // MARK: Subscripting

    public subscript(key: String) -> T? {
        get {
            return objectForKey(key)
        }
        set(newValue) {
            if let value = newValue {
                setObject(value, forKey: key)
            } else {
                removeObjectForKey(key)
            }
        }
    }

    // MARK: Private Helper (not thread safe)

    private func add(object: CacheObject, key: String) {
        // Set object in local cache
        cache.setObject(object, forKey: key)

        // Write object to disk
        if let path = urlForKey(key).path {
            NSKeyedArchiver.archiveRootObject(object, toFile: path)
        }
    }

    private func read(key: String) -> CacheObject? {
        // Check if object exists in local cache
        if let object = cache.objectForKey(key) as? CacheObject {
            return object
        }

        // Otherwise, read from disk
        if let path = self.urlForKey(key).path where self.fileManager.fileExistsAtPath(path) {
            return _awesomeCache_unarchiveObjectSafely(path) as? CacheObject
        }

        return nil
    }

    // Deletes an object from disk
    private func removeFromDisk(key: String) {
        let url = self.urlForKey(key)
        _ = try? self.fileManager.removeItemAtURL(url)
    }


    // MARK: Private Helper

    private func allKeys() -> [String] {
        let urls = try? self.fileManager.contentsOfDirectoryAtURL(self.cacheDirectory, includingPropertiesForKeys: nil, options: [])
        return urls?.flatMap { $0.URLByDeletingPathExtension?.lastPathComponent } ?? []
    }

    private func urlForKey(key: String) -> NSURL {
        let k = sanitizedKey(key)
        return cacheDirectory
            .URLByAppendingPathComponent(k)!
            .URLByAppendingPathExtension("cache")!
    }

    private func sanitizedKey(key: String) -> String {
        return key.stringByReplacingOccurrencesOfString("[^a-zA-Z0-9_]+", withString: "-", options: .RegularExpressionSearch, range: nil)
    }

    private func expiryDateForCacheExpiry(expiry: CacheExpiry) -> NSDate {
        switch expiry {
        case .Never:
            return NSDate.distantFuture()
        case .Seconds(let seconds):
            return NSDate().dateByAddingTimeInterval(seconds)
        case .Date(let date):
            return date
        }
    }
}
