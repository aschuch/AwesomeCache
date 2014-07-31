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
public enum AwesomeCacheExpiry {
	case Never
	case Seconds(NSTimeInterval)
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
public class AwesomeCache<T: NSCoding> {
	public let name: String
	public let directory: String
	
	private let cache = NSCache()
	private let fileManager = NSFileManager()
	private let diskQueue: dispatch_queue_t = dispatch_queue_create("com.aschuch.cache.diskQueue", DISPATCH_QUEUE_SERIAL)
	
	
	// MARK: Initializers
	
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
	public init(name: String, directory: String?) {
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
	 *  @param name		Name of this cache
	 *
	 *  @return			A new cache with the given name and the default cache directory
	 */
	public convenience init(name: String) {
		self.init(name: name, directory: nil)
	}
	
	
	// MARK: Awesome caching
	
	/**
	 *  Returns a cached object immediately or evaluates a cacheBlock. The cacheBlock will not be re-evaluated until the object is expired or manually deleted.
	 *
	 *  If the cache already contains an object, the completion block is called with the cached object immediately.
	 *
	 *	If no object is found or the cached object is already expired, the `cacheBlock` is called.
	 *	You might perform any tasks (e.g. network calls) within this block. Upon completion of these tasks, make sure to call the `success` or `failure` block that is passed to the `cacheBlock`.
	 *  The completion block is invoked as soon as the cacheBlock is finished and the object is cached.
	 *
	 *  @param key			The key to lookup the cached object
	 *  @param cacheBlock	This block gets called if there is no cached object or the cached object is already expired.
	 *						The supplied success or failure blocks must be called upon completion.
	 *						If the error block is called, the object is not cached and the completion block is invoked with this error.
	 *  @param completion	Called as soon as a cached object is available to use. The second parameter is true if the object was already cached.
	 */
	public func setObjectForKey(key: String, cacheBlock: ((T, AwesomeCacheExpiry) -> (), (NSError?) -> ()) -> (), completion: (T?, Bool, NSError?) -> ()) {
		if let object = objectForKey(key) {
			completion(object, true, nil)
		} else {
			let successBlock: (T, AwesomeCacheExpiry) -> () = { (obj, expires) in
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
	
	/**
	 *  Looks up and returns an object with the specified name if it exists.
	 *  If an object is already expired, it is automatically deleted and `nil` will be returned.
	 *  
	 *  @param name		The name of the object that should be returned
	 *  @return			The cached object for the given name, or nil
	 */
	public func objectForKey(key: String) -> T? {
		var possibleObject: AwesomeCacheObject?
				
		// Check if object exists in local cache
		possibleObject = cache.objectForKey(key) as? AwesomeCacheObject
		
		if !possibleObject {
			// Try to load object from disk (synchronously)
			dispatch_sync(diskQueue) {
				let path = self.pathForKey(key)
				if self.fileManager.fileExistsAtPath(path) {
					possibleObject = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? AwesomeCacheObject
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
	
	/**
	 *  Adds a given object to the cache.
	 *
	 *  @param object	The object that should be cached
	 *  @param forKey	A key that represents this object in the cache
	 */
	public func setObject(object: T, forKey key: String) {
		self.setObject(object, forKey: key, expires: .Never)
	}
	
	/**
	 *  Adds a given object to the cache.
	 *  The object is automatically marked as expired as soon as its expiry date is reached.
	 *
	 *  @param object	The object that should be cached
	 *  @param forKey	A key that represents this object in the cache
	 */
	public func setObject(object: T, forKey key: String, expires: AwesomeCacheExpiry) {
		let expiryDate = expiryDateForCacheExpiry(expires)
		let cacheObject = AwesomeCacheObject(value: object, expiryDate: expiryDate)
		
		// Set object in local cache
		cache.setObject(cacheObject, forKey: key)
		
		// Write object to disk (asyncronously)
		dispatch_async(diskQueue) {
			let path = self.pathForKey(key)
			NSKeyedArchiver.archiveRootObject(cacheObject, toFile: path)
		}
	}
	
	
	// MARK: Remove objects
	
	/** 
	 *  Removes an object from the cache.
	 *  
	 *  @param key	The key of the object that should be removed
	 */
	public func removeObjectForKey(key: String) {
		cache.removeObjectForKey(key)
		
		dispatch_async(diskQueue) {
			let path = self.pathForKey(key)
			self.fileManager.removeItemAtPath(path, error: nil)
		}
	}
	
	/**
	 *  Removes all objects from the cache.
	 */
	public func removeAllObjects() {
		cache.removeAllObjects()
		
		dispatch_async(diskQueue) {
			let paths = self.fileManager.contentsOfDirectoryAtPath(self.directory, error: nil) as [String]
			let keys = paths.map { $0.stringByDeletingPathExtension }
			
			for key in keys {
				let path = self.pathForKey(key)
				self.fileManager.removeItemAtPath(path, error: nil)
			}
		}
	}
	
	
	// MARK: Remove Expired Objects
	
	/**
	 *  Removes all expired objects from the cache.
	 */
	public func removeExpiredObjects() {
		dispatch_async(diskQueue) {
			let paths = self.fileManager.contentsOfDirectoryAtPath(self.directory, error: nil) as [String]
			let keys = paths.map { $0.stringByDeletingPathExtension }
			
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
	
	private func pathForKey(key: String) -> String {
		return directory.stringByAppendingPathComponent(key).stringByAppendingPathExtension("cache")
	}

	private func expiryDateForCacheExpiry(expiry: AwesomeCacheExpiry) -> NSDate {
		switch expiry {
		case .Never:
			return NSDate.distantFuture() as NSDate
		case .Seconds(let seconds):
			return NSDate().dateByAddingTimeInterval(seconds)
		case .Date(let date):
			return date
		}
	}
}

