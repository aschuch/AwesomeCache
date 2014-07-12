//
//  Cache.swift
//  Example
//
//  Created by Alexander Schuch on 12/07/14.
//  Copyright (c) 2014 Alexander Schuch. All rights reserved.
//

import Foundation

/**
 *  Represents the expiry of a cached object
 */
enum CacheExpiry {
	case Never
	case InSeconds(NSTimeInterval)
	case Date(NSDate)
}

/**
 *  A generic cache that persists objects to disk and is backed by a NSCache.
 *  Supports an expiry date for every cached object. Expired objects are automatically deleted upon their next access via `objectForKey:`. 
 *  If you want to delete expired objects, call `removeAllExpiredObjects`.
 *
 *  Subclassing notes: This class fully supports subclassing. 
 *  The easiest way to implement a subclass is to override `objectForKey` and `setObject:forKey:expires:`, e.g. to modify values prior to reading/writing to the cache.
 */
class Cache<T: NSCoding> {
	let name: String		// @readonly
	let directory: String	// @readonly
	
	// @private
	let cache = NSCache()
	let fileManager = NSFileManager()
	let diskQueue: dispatch_queue_t = dispatch_queue_create("com.aschuch.cache.diskQueue", DISPATCH_QUEUE_SERIAL)
	
	
	/// Initializers
	
	/**
	 *  Designated initializer.
	 * 
	 *  @param name			Name of this cache
	 *	@param directory	Objects in this cache are persisted to this directory. 
	 *						If no directory is specified, a new directory is created in the system's Caches directory
	 *
	 *  @return				A new cache with the given name and directory
	 *
	 */
	init(name: String, directory: String?) {
		// Ensure directory name
		var dir: String? = directory
		if !dir {
			let cacheDirectory = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0] as String
			dir = cacheDirectory.stringByAppendingFormat("/com.aschuch.cache/%@", name)
		}
		self.directory = dir!
		
		self.name = name
		cache.name = name
		
		// Create directory on disk
		if !fileManager.fileExistsAtPath(self.directory) {
			fileManager.createDirectoryAtPath(self.directory, withIntermediateDirectories: true, attributes: nil, error: nil)
		}
	}
	
	/**
	 *  @param name			Name of this cache
	 *
	 *  @return				A new cache with the given name and the default cache directory
	 */
	convenience init(name: String) {
		self.init(name: name, directory: nil)
	}
	
	
	/// Awesome caching
	
	/**
	 *  Returns a cached object immediately or evaluates a cacheBlock. The cacheBlock is not re-evaluated until the object is expired or manually deleted.
	 *
	 *  First looks up an object with the given key. If no object was found or the cached object is already expired, the `cacheBlock` is called.
	 *  You can perform any tasks (e.g. network calls) within this block. Upon completion of these tasks, make sure to call the completion block that is passed to the `cacheBlock`.
	 *  The completion block is called immediately, if the cache already contains an object for the given key. Otherwise it is called as soon as the `cacheBlock` completes and the object is cached.
	 *  
	 *  @param key			The key for the cached object
	 *  @param cacheBlock	This block gets called if there is no cached object or this object is already expired.
	 *						The supplied block must be called upon completion (with the object to cache and its expiry).
	 *  @param completaion	Called as soon as a cached object is available to use. The second parameter is true if the object was already cached.
	 */
	func setObjectForKey(key: String, cacheBlock: ((T, CacheExpiry) -> ()) -> (), completion: (T, Bool) -> ()) {
		if let object = objectForKey(key) {
			completion(object, true)
		} else {
			let cacheReturnBlock: (T, CacheExpiry) -> () = { (obj, expires) in
				self.setObject(obj, forKey: key, expires: expires)
				completion(obj, false)
			}
			cacheBlock(cacheReturnBlock)
		}
	}
	
	
	/// Get object
	
	/**
	 *  Looks up and returns an object with the specified name if it exists.
	 *  If an object is already expired, it is automatically deleted and `nil` will be returned.
	 *  
	 *  @param name		The name of the object that should be returned
	 *  @return			The cached object for the given name, or nil
	 */
	func objectForKey(key: String) -> T? {
		var possibleObject: CacheObject?
				
		// Check if object exists in local cache
		possibleObject = cache.objectForKey(key) as? CacheObject
		
		if !possibleObject {
			// Try to load object from disk (synchronously)
			dispatch_sync(diskQueue) {
				let path = self._pathForKey(key)
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
	
	
	/// Set object
	
	/**
	 *  Adds a given object to the cache.
	 *
	 *  @param object	The object that should be cached
	 *  @param forKey	A key that represents this object in the cache
	 */
	func setObject(object: T, forKey key: String) {
		self.setObject(object, forKey: key, expires: .Never)
	}
	
	/**
	 *  Adds a given object to the cache.
	 *  The object is automatically marked as expired as soon as its expiry date is reached.
	 *
	 *  @param object	The object that should be cached
	 *  @param forKey	A key that represents this object in the cache
	 */
	func setObject(object: T, forKey key: String, expires: CacheExpiry) {
		let expiryDate = _expiryDateForCacheExpiry(expires)
		let cacheObject = CacheObject(value: object, expiryDate: expiryDate)
		
		// Set object in local cache
		cache.setObject(cacheObject, forKey: key)
		
		// Write object to disk (asyncronously)
		dispatch_async(diskQueue) {
			let path = self._pathForKey(key)
			NSKeyedArchiver.archiveRootObject(cacheObject, toFile: path)
		}
	}
	
	
	/// Remove objects
	
	/** 
	 *  Removes an object from the cache.
	 *  
	 *  @param key	The key of the object that should be removed
	 */
	func removeObjectForKey(key: String) {
		cache.removeObjectForKey(key)
		
		dispatch_async(diskQueue) {
			let path = self._pathForKey(key)
			self.fileManager.removeItemAtPath(path, error: nil)
		}
	}
	
	/**
	 *  Removes all objects from the cache.
	 */
	func removeAllObjects() {
		cache.removeAllObjects()
		
		dispatch_async(diskQueue) {
			let paths = self.fileManager.contentsOfDirectoryAtPath(self.directory, error: nil) as [String]
			for path in paths {
				self.fileManager.removeItemAtPath(path, error: nil)
			}
		}
	}
	
	
	/// Remove Expired Objects
	
	/**
	 *  Removes all expired objects from the cache.
	 */
	func removeExpiredObjects() {
		dispatch_async(diskQueue) {
			let paths = self.fileManager.contentsOfDirectoryAtPath(self.directory, error: nil) as [String]
			let keys = paths.map { $0.lastPathComponent.stringByDeletingPathExtension }
			
			for key in keys {
				// `objectForKey:` deletes the object if it is expired
				self.objectForKey(key)
			}
		}
	}
	
	
	/// Subscripting
	
	subscript(key: String) -> T? {
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
	
	
	/// @private Helper
	
	/**
     *  @private
     */
	func _pathForKey(key: String) -> String {
		return directory.stringByAppendingPathComponent(key).stringByAppendingPathExtension("cache")
	}
	
	/**
	 *  @private
     */
	func _expiryDateForCacheExpiry(expiry: CacheExpiry) -> NSDate {
		switch expiry {
		case .Never:
			return NSDate.distantFuture() as NSDate
		case .InSeconds(let seconds):
			return NSDate().dateByAddingTimeInterval(seconds)
		case .Date(let date):
			return date
		}
	}
}

