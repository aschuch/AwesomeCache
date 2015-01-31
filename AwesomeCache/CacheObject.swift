//
//  CacheObject.swift
//  Example
//
//  Created by Alexander Schuch on 12/07/14.
//  Copyright (c) 2014 Alexander Schuch. All rights reserved.
//

import Foundation

/**
 * This class is a wrapper around an objects that should be cached to disk.
 *
 * NOTE: It is currently not possible to use generics with a subclass of NSObject
 *		 However, NSKeyedArchiver needs a concrete subclass of NSObject to work correctly
 */
class CacheObject : NSObject, NSCoding {
	let value: AnyObject
	let expiryDate: NSDate
	
	/**
	 *  Designated initializer. 
	 *
     *  @param value			An object that should be cached
	 *  @param expiryDate	The expiry date of the given value
     */
	init(value: AnyObject, expiryDate: NSDate) {
		self.value = value
		self.expiryDate = expiryDate
	}
	
	/**
     *  Returns true if this object is expired.
	 *  Expiry of the object is determined by its expiryDate.
     */
	func isExpired() -> Bool {
		let expires = expiryDate.timeIntervalSinceNow
		let now = NSDate().timeIntervalSinceNow
		
		return now > expires
	}
	
	
	/// NSCoding

	required init(coder aDecoder: NSCoder) {
		value = aDecoder.decodeObjectForKey("value") as AnyObject!
		expiryDate = aDecoder.decodeObjectForKey("expiryDate") as NSDate

		super.init()
	}
	
	func encodeWithCoder(aCoder: NSCoder) {
		aCoder.encodeObject(value, forKey: "value")
		aCoder.encodeObject(expiryDate, forKey: "expiryDate")
	}
}
