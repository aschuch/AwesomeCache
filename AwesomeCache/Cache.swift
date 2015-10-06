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
	private let diskWriteQueue: dispatch_queue_t = dispatch_queue_create("com.aschuch.cache.diskWriteQueue", DISPATCH_QUEUE_SERIAL)
	private let diskReadQueue: dispatch_queue_t = dispatch_queue_create("com.aschuch.cache.diskReadQueue", DISPATCH_QUEUE_SERIAL)
	
	
	// MARK: Initializers
	
	/// Designated initializer.
	///
	/// - parameter name: Name of this cache
	///	- parameter directory:  Objects in this cache are persisted to this directory.
	///                         If no directory is specified, a new directory is created in the system's Caches directory
	///
	///  - returns:	A new cache with the given name and directory
	public init(name: String, directory: NSURL?) throws {
		self.name = name
		cache.name = name
		
		if let d = directory {
			cacheDirectory = d
		} else {
            let url = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).first!
			cacheDirectory = url.URLByAppendingPathComponent("com.aschuch.cache/\(name)")
		}
		
		// Create directory on disk if needed
        try fileManager.createDirectoryAtURL(cacheDirectory, withIntermediateDirectories: true, attributes: nil)
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
	public func setObjectForKey(key: String, cacheBlock: ((T, CacheExpiry) -> (), (NSError?) -> ()) -> (), completion: (T?, Bool, NSError?) -> ()) {
		if let object = objectForKey(key) {
			completion(object, true, nil)
		} else {
			let successBlock: (T, CacheExpiry) -> () = { (obj, expires) in
				self.setObject(obj, forKey: key, expires: expires)
				completion(obj, false, nil)
			}
			
			let failureBlock: (NSError?) -> () = { (error) in
				completion(nil, false, error)
			}
			
			cacheBlock(successBlock, failureBlock)
		}
	}
	
	
	// MARK: Get object
	
    /// Looks up and returns an object with the specified name if it exists.
    /// If an object is already expired, it is automatically deleted and `nil` will be returned.
    ///
    /// - parameter key: The name of the object that should be returned
    ///
    /// - returns: The cached object for the given name, or nil
	public func objectForKey(key: String) -> T? {
		var possibleObject: CacheObject?
				
		// Check if object exists in local cache
		possibleObject = cache.objectForKey(key) as? CacheObject
		
		if possibleObject == nil {
			// Try to load object from disk (synchronously)
			dispatch_sync(diskReadQueue) {
				let path = self.urlForKey(key).path!
				if self.fileManager.fileExistsAtPath(path) {
					possibleObject = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? CacheObject
				}
			}
		}
		
		// Check if object is not already expired and return
		// Delete object if expired
		if let object = possibleObject {
			if !object.isExpired() {
				return object.value as? T
			} else {
				removeObjectForKey(key)
			}
		}
		
		return nil
	}
	
	
	// MARK: Set object
	
	/// Adds a given object to the cache.
	/// The object is automatically marked as expired as soon as its expiry date is reached.
	///
	/// - parameter object:	The object that should be cached
	/// - parameter forKey:	A key that represents this object in the cache
    /// - parameter expires: The CacheExpiry that indicates when the given object should be expired
    public func setObject(object: T, forKey key: String, expires: CacheExpiry = .Never) {
        setObject(object, forKey: key, expires: expires, completion: { })
    }
    
    /// For internal testing only, might add this to the public API if needed
    internal func setObject(object: T, forKey key: String, expires: CacheExpiry = .Never, completion: () -> ()) {
        let expiryDate = expiryDateForCacheExpiry(expires)
        let cacheObject = CacheObject(value: object, expiryDate: expiryDate)
        
        // Set object in local cache
        cache.setObject(cacheObject, forKey: key)
        
        // Write object to disk (asyncronously)
        dispatch_async(diskWriteQueue) {
            let path = self.urlForKey(key).path!
            NSKeyedArchiver.archiveRootObject(cacheObject, toFile: path)
            completion()
        }
    }
	
	
	// MARK: Remove objects
	
	/// Removes an object from the cache.
	///
	/// - parameter key: The key of the object that should be removed
	public func removeObjectForKey(key: String) {
		cache.removeObjectForKey(key)
		
		dispatch_async(diskWriteQueue) {
			let url = self.urlForKey(key)
			do {
				try self.fileManager.removeItemAtURL(url)
			} catch _ {}
		}
	}
	
	/// Removes all objects from the cache.
	///
	/// - parameter completion:	Called as soon as all cached objects are removed from disk.
	public func removeAllObjects(completion: (() -> Void)? = nil) {
		cache.removeAllObjects()
		
		dispatch_async(diskWriteQueue) {
            let keys = self.allKeys()
			
            for key in keys {
				let url = self.urlForKey(key)
				do {
					try self.fileManager.removeItemAtURL(url)
				} catch _ {}
			}

			dispatch_async(dispatch_get_main_queue()) {
				completion?()
			}
		}
	}
	
	
	// MARK: Remove Expired Objects
	
	/// Removes all expired objects from the cache.
	public func removeExpiredObjects() {
		dispatch_async(diskWriteQueue) {
            let keys = self.allKeys()
			
			for key in keys {
				// `objectForKey:` deletes the object if it is expired
				self.objectForKey(key)
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
	
	
	// MARK: Private Helper
    
    private func allKeys() -> [String] {
        let urls = try? self.fileManager.contentsOfDirectoryAtURL(self.cacheDirectory, includingPropertiesForKeys: nil, options: [])
        return urls?.flatMap { $0.URLByDeletingPathExtension?.lastPathComponent } ?? []
    }
	
	private func urlForKey(key: String) -> NSURL {
		let k = sanitizedKey(key)
		return cacheDirectory
                .URLByAppendingPathComponent(k)
                .URLByAppendingPathExtension("cache")
	}
	
	private func sanitizedKey(key: String) -> String {
		let regex = try! NSRegularExpression(pattern: "[^a-zA-Z0-9_]+", options: NSRegularExpressionOptions())
		let range = NSRange(location: 0, length: key.characters.count)
		return regex.stringByReplacingMatchesInString(key, options: NSMatchingOptions(), range: range, withTemplate: "-")
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
