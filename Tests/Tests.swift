//
//  ExampleTests.swift
//  ExampleTests
//
//  Created by Alexander Schuch on 12/07/14.
//  Copyright (c) 2014 Alexander Schuch. All rights reserved.
//

import UIKit
import XCTest

import Example

class ExampleTests: XCTestCase {
	
	var cache: AwesomeCache<NSString> = AwesomeCache<NSString>(name: "awesomeCache")
	
    override func setUp() {
		cache = AwesomeCache<NSString>(name: "awesomeCache")
		
		super.setUp()
    }
    
    override func tearDown() {
		cache.removeAllObjects()
		
		super.tearDown()
    }
	
	func testGetterAndSetter() {
		let nilObject = cache.objectForKey("unavailable")
		XCTAssertNil(nilObject, "Get nil object")
		
		cache.setObject("AddedString", forKey: "add")
		XCTAssertNotNil(cache.objectForKey("add"), "Get non-nil object")
		XCTAssertEqual("AddedString", cache.objectForKey("add")!, "Get non-nil object")
	}
	
	func testRemoveObject() {
		cache.setObject("AddedString", forKey: "remove")
		XCTAssertNotNil(cache.objectForKey("add"), "Get non-nil object")
		XCTAssertEqual("AddedString", cache.objectForKey("remove")!, "Get non-nil object")
		
		cache.removeObjectForKey("remove")
		XCTAssertNil(cache.objectForKey("remove"), "Get deleted object")
	}
	
	func testSubscripting() {
		cache["addSubscript"] = "AddedString"
		XCTAssertNotNil(cache["addSubscript"], "Get non-nil object via subscript")
		XCTAssertEqual("AddedString", cache["addSubscript"]!, "Get non-nil object via subscript")
		
		cache["addSubscript"] = nil
		XCTAssertNil(cache["addSubscript"], "Get deleted object via subscript")
	}
	
	func testObjectExpiry() {
		cache.setObject("NeverExpires", forKey: "never", expires: .Never)
		cache.setObject("ExpiresIn2Seconds", forKey: "2Seconds", expires: .Seconds(2))
		cache.setObject("ExpiresAtDate", forKey: "atDate", expires: .Date(NSDate().dateByAddingTimeInterval(4)))
		
		XCTAssertNotNil(cache.objectForKey("never"), "Never expires")
		XCTAssertNotNil(cache.objectForKey("2Seconds"), "Expires in 2 seconds")
		XCTAssertNotNil(cache.objectForKey("atDate"), "Expires in 4 seconds")
		
		sleep(2)
		
		XCTAssertNotNil(cache.objectForKey("never"), "Never expires")
		XCTAssertNil(cache.objectForKey("2Seconds"), "Expires in 2 seconds")
		XCTAssertNotNil(cache.objectForKey("atDate"), "Expires in 4 seconds")
		
		sleep(2)
		
		XCTAssertNotNil(cache.objectForKey("never"), "Never expires")
		XCTAssertNil(cache.objectForKey("2Seconds"), "Expires in 2 seconds")
		XCTAssertNil(cache.objectForKey("atDate"), "Expires in 3 seconds")
	}
	
	func testCacheBlockExecuted() {
		var executed = false
		
		cache.setObjectForKey("blockExecuted", cacheBlock: { returnBlock in
			executed = true
			returnBlock("AddedString", .Never)
		}, completion: { object, isCached in
			XCTAssertEqual("AddedString", object, "Get cached object")
			
			XCTAssertNotNil(self.cache.objectForKey("blockExecuted"), "Get cached object")
			XCTAssertTrue(executed, "Block was executed")
		})
	}
	
	func testCacheBlockNotExecuted() {
		var executed = false
		
		cache.setObject("AddedString", forKey: "blockNotExecuted")
		
		cache.setObjectForKey("blockNotExecuted", cacheBlock: { returnBlock in
			executed = true
			returnBlock("SometingElse", .Never)
		}, completion: { object, isCached in
			XCTAssertEqual("AddedString", object, "Get cached object")
			
			XCTAssertEqual("AddedString", self.cache.objectForKey("blockNotExecuted")!, "Get cached object")
			XCTAssertNotNil(self.cache.objectForKey("blockNotExecuted"), "Get cached object")
			XCTAssertFalse(executed, "Block was not executed")
		})
	}
}
