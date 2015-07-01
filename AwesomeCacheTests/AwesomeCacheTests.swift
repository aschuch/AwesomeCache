//
//  AwesomeCacheTests.swift
//  AwesomeCacheTests
//
//  Created by Alexander Schuch on 31/01/15.
//  Copyright (c) 2015 Alexander Schuch. All rights reserved.
//

import UIKit
import XCTest
import AwesomeCache

class AwesomeCacheTests: XCTestCase {
    
    var cache: Cache<NSString> = try! Cache<NSString>(name: "awesomeCache")
    
    override func setUp() {
        cache = try! Cache<NSString>(name: "awesomeCache")
        cache.removeAllObjects()
        
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
        XCTAssertNotNil(cache.objectForKey("remove"), "Get non-nil object")
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
    
    func testInvalidKey() {
        let key = "//$%foobar--893"
        cache.setObject("AddedString", forKey: key)
        XCTAssertNotNil(cache.objectForKey(key), "Get non-nil object")
        XCTAssertEqual("AddedString", cache.objectForKey(key)!, "Get non-nil object")
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
        
        cache.setObjectForKey("blockExecuted", cacheBlock: { successBlock, failureBlock in
            executed = true
            successBlock("AddedString", .Never)
            }, completion: { object, isLoadedFromCache, error in
                XCTAssertNotNil(object, "Cached object not nil")
                XCTAssertEqual("AddedString", object!, "Get cached object")
                
                XCTAssertNotNil(self.cache.objectForKey("blockExecuted"), "Get cached object")
                XCTAssertTrue(executed, "Block was executed")
                XCTAssertFalse(isLoadedFromCache, "Object was not loaded cached")
                XCTAssertNil(error, "Error is nil")
        })
    }
    
    func testCacheBlockNotExecuted() {
        var executed = false
        
        cache.setObject("AddedString", forKey: "blockNotExecuted")
        
        cache.setObjectForKey("blockNotExecuted", cacheBlock: { successBlock, failureBlock in
            executed = true
            successBlock("SometingElse", .Never)
            }, completion: { object, isLoadedFromCache, error in
                XCTAssertNotNil(object, "Cached object not nil")
                XCTAssertEqual("AddedString", object!, "Get cached object")
                
                XCTAssertNotNil(self.cache.objectForKey("blockNotExecuted"), "Get cached object")
                XCTAssertEqual("AddedString", self.cache.objectForKey("blockNotExecuted")!, "Get cached object")
                
                XCTAssertFalse(executed, "Block was not executed")
                XCTAssertTrue(isLoadedFromCache, "Object was loaded from cached")
                XCTAssertNil(error, "Error is nil")
        })
    }
    
    
    func testCacheBlockError() {
        
        cache.setObjectForKey("blockError", cacheBlock: { successBlock, failureBlock in
            let error = NSError(domain: "AwesomeCacheErrorDomain", code: 42, userInfo: nil)
            failureBlock(error)
            }, completion: { object, isLoadedFromCache, error in
                XCTAssertNil(object, "Cached object nil")
                XCTAssertNil(self.cache.objectForKey("blockError"), "Get cached object")
                
                XCTAssertFalse(isLoadedFromCache, "Object was loaded from cached")
                XCTAssertNotNil(error, "Error is nil")
                XCTAssert(error!.domain == "AwesomeCacheErrorDomain", "Error domain")
                XCTAssert(error!.code == 42, "Error code")
        })
        
        
    }

}
