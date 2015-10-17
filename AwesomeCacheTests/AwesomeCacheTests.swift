//
//  AwesomeCacheTests.swift
//  AwesomeCacheTests
//
//  Created by Alexander Schuch on 31/01/15.
//  Copyright (c) 2015 Alexander Schuch. All rights reserved.
//

import UIKit
import XCTest
@testable import AwesomeCache

class AwesomeCacheTests: XCTestCase {
 
    func testGetterAndSetter() {
        let cache = try! Cache<NSString>(name: "testGetterAndSetter")
        
        let nilObject = cache.objectForKey("unavailable")
        XCTAssertNil(nilObject, "Get nil object")
        
        cache.setObject("AddedString", forKey: "add")
        XCTAssertNotNil(cache.objectForKey("add"), "Get non-nil object")
        XCTAssertEqual("AddedString", cache.objectForKey("add")!, "Get non-nil object")
    }
    
    func testRemoveObject() {
        let cache = try! Cache<NSString>(name: "testRemoveObject")
        
        cache.setObject("AddedString", forKey: "remove")
        XCTAssertNotNil(cache.objectForKey("remove"), "Get non-nil object")
        XCTAssertEqual("AddedString", cache.objectForKey("remove")!, "Get non-nil object")
        
        cache.removeObjectForKey("remove")
        XCTAssertNil(cache.objectForKey("remove"), "Get deleted object")
    }

    func testRemoveAllObjects() {
        let cache = try! Cache<NSString>(name: "testRemoveAllObjects")
        
        cache.setObject("AddedString 1", forKey: "remove 1")
        cache.setObject("AddedString 2", forKey: "remove 2")
        XCTAssertNotNil(cache.objectForKey("remove 1"), "Get first non-nil object")
        XCTAssertNotNil(cache.objectForKey("remove 2"), "Get second non-nil object")

        let expectation = expectationWithDescription("Remove All Objects")

        cache.removeAllObjects {
            XCTAssertNil(cache.objectForKey("remove 1"), "Get first deleted object")
            XCTAssertNil(cache.objectForKey("remove 2"), "Get second deleted object")
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(4) { error in
            if let error = error {
                print("\n\n\nError: \(error.localizedDescription)\n\n\n")
            }
        }
    }
    
    func testSubscripting() {
        let cache = try! Cache<NSString>(name: "testSubscripting")
        
        cache["addSubscript"] = "AddedString"
        XCTAssertNotNil(cache["addSubscript"], "Get non-nil object via subscript")
        XCTAssertEqual("AddedString", cache["addSubscript"]!, "Get non-nil object via subscript")
        
        cache["addSubscript"] = nil
        XCTAssertNil(cache["addSubscript"], "Get deleted object via subscript")
    }
    
    func testInvalidKey() {
        let cache = try! Cache<NSString>(name: "testInvalidKey")
        
        let key = "//$%foobar--893"
        cache.setObject("AddedString", forKey: key)
        XCTAssertNotNil(cache.objectForKey(key), "Get non-nil object")
        XCTAssertEqual("AddedString", cache.objectForKey(key)!, "Get non-nil object")
    }
    
    func testObjectExpiry() {
        let cache = try! Cache<NSString>(name: "testObjectExpiry")
        
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
        let cache = try! Cache<NSString>(name: "testCacheBlockExecuted")
        var executed = false
        
        cache.setObjectForKey("blockExecuted", cacheBlock: { successBlock, failureBlock in
            executed = true
            successBlock("AddedString", .Never)
        }, completion: { object, isLoadedFromCache, error in
            XCTAssertNotNil(object, "Cached object not nil")
            XCTAssertEqual("AddedString", object!, "Get cached object")
                
            XCTAssertNotNil(cache.objectForKey("blockExecuted"), "Get cached object")
            XCTAssertTrue(executed, "Block was executed")
            XCTAssertFalse(isLoadedFromCache, "Object was not loaded cached")
            XCTAssertNil(error, "Error is nil")
        })
    }
    
    func testCacheBlockNotExecuted() {
        let cache = try! Cache<NSString>(name: "testCacheBlockNotExecuted")
        var executed = false
        
        cache.setObject("AddedString", forKey: "blockNotExecuted")
        
        cache.setObjectForKey("blockNotExecuted", cacheBlock: { successBlock, failureBlock in
            executed = true
            successBlock("SometingElse", .Never)
        }, completion: { object, isLoadedFromCache, error in
            XCTAssertNotNil(object, "Cached object not nil")
            XCTAssertEqual("AddedString", object!, "Get cached object")
                
            XCTAssertNotNil(cache.objectForKey("blockNotExecuted"), "Get cached object")
            XCTAssertEqual("AddedString", cache.objectForKey("blockNotExecuted")!, "Get cached object")
                
            XCTAssertFalse(executed, "Block was not executed")
            XCTAssertTrue(isLoadedFromCache, "Object was loaded from cached")
            XCTAssertNil(error, "Error is nil")
        })
    }
    
    func testCacheBlockError() {
        let cache = try! Cache<NSString>(name: "testCacheBlockError")
        
        cache.setObjectForKey("blockError", cacheBlock: { successBlock, failureBlock in
            let error = NSError(domain: "AwesomeCacheErrorDomain", code: 42, userInfo: nil)
            failureBlock(error)
        }, completion: { object, isLoadedFromCache, error in
            XCTAssertNil(object, "Cached object nil")
            XCTAssertNil(cache.objectForKey("blockError"), "Get cached object")
                
            XCTAssertFalse(isLoadedFromCache, "Object was loaded from cached")
            XCTAssertNotNil(error, "Error is nil")
            XCTAssert(error!.domain == "AwesomeCacheErrorDomain", "Error domain")
            XCTAssert(error!.code == 42, "Error code")
        })
    }

    func testDiskPersistance() {
        let cache = try! Cache<NSString>(name: "testDiskPersistance")
        
        cache.setObject("foobar", forKey: "persistedObject", completion: {
            let beforeObject = cache.objectForKey("persistedObject")
            XCTAssertNotNil(beforeObject)
            
            // Remove all objects from internal NSCache
            // to force reload from disk
            cache.cache.removeAllObjects()
            
            let afterObject = cache.objectForKey("persistedObject")
            XCTAssertNotNil(afterObject)
        })
    }
    
}
