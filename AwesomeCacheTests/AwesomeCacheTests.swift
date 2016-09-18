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

    func testCustomCachePath() {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cache = try! Cache<NSString>(name: "CustomCachePath", directory: url)

        cache.setObject("AddedString", forKey: "add")
        XCTAssertNotNil(cache.object(forKey: "add"), "Added object should not be nil")
    }

    func testGetterAndSetter() {
        let cache = try! Cache<NSString>(name: "testGetterAndSetter")

        let nilObject = cache.object(forKey: "unavailable")
        XCTAssertNil(nilObject, "Getting an unavailable object should return nil")

        cache.setObject("AddedString", forKey: "add")
        XCTAssertNotNil(cache.object(forKey: "add"), "Added object should not be nil")
        XCTAssertEqual("AddedString", cache.object(forKey: "add")!, "Fetched object should be equal to the inserted object")
    }

    func testGetExpiredObjectIfPresent() {
        let cache = try! Cache<NSString>(name: "testGetExpiredObject")

        cache.setObject("AlreadyExpired", forKey: "alreadyExpired", expires: .date(Date().addingTimeInterval(-1)))

        XCTAssertNotNil(cache.object(forKey: "alreadyExpired", returnExpiredObjectIfPresent: true), "Already expired object should be returned when `returnExpiredObjectIfPresent` is true")
        XCTAssertNil(cache.object(forKey: "alreadyExpired"), "Already expired object should not be returned when `returnExpiredObjectIfPresent` is not set")
    }

    func testRemoveObject() {
        let cache = try! Cache<NSString>(name: "testRemoveObject")

        cache.setObject("AddedString", forKey: "remove")
        XCTAssertNotNil(cache.object(forKey: "remove"), "Added object should not be nil")
        XCTAssertEqual("AddedString", cache.object(forKey: "remove")!, "Fetched object should be equal to the inserted object")

        cache.removeObject(forKey: "remove")
        XCTAssertNil(cache.object(forKey: "remove"), "Removed object should be nil")
    }

    func testRemoveAllObjects() {
        let cache = try! Cache<NSString>(name: "testRemoveAllObjects")

        cache.setObject("AddedString 1", forKey: "remove 1")
        cache.setObject("AddedString 2", forKey: "remove 2")
        XCTAssertNotNil(cache.object(forKey: "remove 1"), "Added object should not be nil")
        XCTAssertNotNil(cache.object(forKey: "remove 2"), "Added object should not be nil")

        cache.removeAllObjects()
        XCTAssertNil(cache.object(forKey: "remove 1"), "Removed object should be nil")
        XCTAssertNil(cache.object(forKey: "remove 2"), "Removed object should be nil")
    }

    func testRemoveExpiredObjects() {
        let cache = try! Cache<NSString>(name: "testRemoveExpiredObjects")

        cache.setObject("NeverExpires", forKey: "never", expires: .never)
        cache.setObject("ExpiresIn2Seconds", forKey: "2Seconds", expires: .seconds(2))
        cache.removeExpiredObjects()

        XCTAssertNotNil(cache.object(forKey: "never"), "Added object should not be nil since it never expires")
        XCTAssertNotNil(cache.object(forKey: "2Seconds"), "Added object should not be nil since 2 seconds have not passed")

        sleep(3)

        cache.removeExpiredObjects()
        XCTAssertNotNil(cache.object(forKey: "never"), "Object should not be nil since it never expires")
        XCTAssertNil(cache.object(forKey: "2Seconds"), "Object should be nil since 2 seconds have passed")
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
        XCTAssertNotNil(cache.object(forKey: key), "Added object should not be nil")
        XCTAssertEqual("AddedString", cache.object(forKey: key)!, "Fetched object should be equal to the inserted object")
    }

    func testObjectExpiry() {
        let cache = try! Cache<NSString>(name: "testObjectExpiry")

        cache.setObject("NeverExpires", forKey: "never", expires: .never)
        cache.setObject("ExpiresIn2Seconds", forKey: "2Seconds", expires: .seconds(2))
        cache.setObject("ExpiresAtDate", forKey: "atDate", expires: .date(Date().addingTimeInterval(4)))

        XCTAssertNotNil(cache.object(forKey: "never"), "Never expires")
        XCTAssertNotNil(cache.object(forKey: "2Seconds"), "Expires in 2 seconds")
        XCTAssertNotNil(cache.object(forKey: "atDate"), "Expires in 4 seconds")

        sleep(2)

        XCTAssertNotNil(cache.object(forKey: "never"), "Never expires")
        XCTAssertNil(cache.object(forKey: "2Seconds"), "Expires in 2 seconds")
        XCTAssertNotNil(cache.object(forKey: "atDate"), "Expires in 4 seconds")

        sleep(2)

        XCTAssertNotNil(cache.object(forKey: "never"), "Never expires")
        XCTAssertNil(cache.object(forKey: "2Seconds"), "Expires in 2 seconds")
        XCTAssertNil(cache.object(forKey: "atDate"), "Expires in 3 seconds")
    }

    func testAllObjects() {
        let cache = try! Cache<NSString>(name: "testAllObjects")

        cache.setObject("NeverExpires", forKey: "never", expires: .never)
        cache.setObject("ExpiresIn2Seconds", forKey: "2Seconds", expires: .seconds(2))
        cache.setObject("ExpiresAtDate", forKey: "atDate", expires: .date(Date().addingTimeInterval(4)))

        sleep(2)

        let all = cache.allObjects()

        XCTAssertTrue(all.count == 2, "2 returned objects")
        XCTAssertTrue(all.contains("NeverExpires"), "Never expires")
        XCTAssertFalse(all.contains("ExpiresIn2Seconds"), "Expires in 2 seconds")
        XCTAssertTrue(all.contains("ExpiresAtDate"), "Expires in 4 seconds")

        let expiredIncluded = cache.allObjects(includeExpired: true)
        XCTAssertTrue(expiredIncluded.count == 3, "3 returned objects")
        XCTAssertTrue(expiredIncluded.contains("NeverExpires"), "Never expires")
        XCTAssertTrue(expiredIncluded.contains("ExpiresIn2Seconds"), "Expires in 2 seconds")
        XCTAssertTrue(expiredIncluded.contains("ExpiresAtDate"), "Expires in 4 seconds")
    }

    func testRemoveAllExpiredObjects() {
        let cache = try! Cache<NSString>(name: "testRemoveAllExpiredObjects")

        cache.setObject("NeverExpires", forKey: "never", expires: .never)
        cache.setObject("AlreadyExpired", forKey: "alreadyExpired", expires: .date(Date().addingTimeInterval(-1)))

        cache.cache.removeAllObjects() // Prevent the in-memory cache to return the object when trying to read the expiration date
        cache.removeExpiredObjects()

        XCTAssertNotNil(cache.object(forKey: "never"), "Never expires")
        XCTAssertNil(cache.object(forKey: "alreadyExpired"), "Already expired")
    }

    func testCacheBlockExecuted() {
        let cache = try! Cache<NSString>(name: "testCacheBlockExecuted")
        var executed = false

        cache.setObject(forKey: "blockExecuted", cacheBlock: { successBlock, failureBlock in
            executed = true
            successBlock("AddedString", .never)
        }, completion: { object, isLoadedFromCache, error in
            XCTAssertNotNil(object, "Cached object not nil")
            XCTAssertEqual("AddedString", object!, "Get cached object")

            XCTAssertNotNil(cache.object(forKey: "blockExecuted"), "Get cached object")
            XCTAssertTrue(executed, "Block was executed")
            XCTAssertFalse(isLoadedFromCache, "Object was not loaded cached")
            XCTAssertNil(error, "Error is nil")
        })

        // Make sure to always drain the cache
        cache.removeAllObjects()
    }

    func testCacheBlockNotExecuted() {
        let cache = try! Cache<NSString>(name: "testCacheBlockNotExecuted")
        var executed = false

        cache.setObject("AddedString", forKey: "blockNotExecuted")

        cache.setObject(forKey: "blockNotExecuted", cacheBlock: { successBlock, failureBlock in
            executed = true
            successBlock("SometingElse", .never)
        }, completion: { object, isLoadedFromCache, error in
            XCTAssertNotNil(object, "Cached object not nil")
            XCTAssertEqual("AddedString", object!, "Get cached object")

            XCTAssertNotNil(cache.object(forKey: "blockNotExecuted"), "Get cached object")
            XCTAssertEqual("AddedString", cache.object(forKey: "blockNotExecuted")!, "Get cached object")

            XCTAssertFalse(executed, "Block was not executed")
            XCTAssertTrue(isLoadedFromCache, "Object was loaded from cached")
            XCTAssertNil(error, "Error is nil")
        })
    }

    func testCacheBlockError() {
        let cache = try! Cache<NSString>(name: "testCacheBlockError")

        cache.setObject(forKey: "blockError", cacheBlock: { successBlock, failureBlock in
            let error = NSError(domain: "AwesomeCacheErrorDomain", code: 42, userInfo: nil)
            failureBlock(error)
        }, completion: { object, isLoadedFromCache, error in
            XCTAssertNil(object, "Cached object nil")
            XCTAssertNil(cache.object(forKey: "blockError"), "Get cached object")

            XCTAssertFalse(isLoadedFromCache, "Object was loaded from cached")
            XCTAssertNotNil(error, "Error is nil")
            XCTAssert(error!.domain == "AwesomeCacheErrorDomain", "Error domain")
            XCTAssert(error!.code == 42, "Error code")
        })
    }

    func testDiskPersistance() {
        let cache = try! Cache<NSString>(name: "testDiskPersistance")

        cache.setObject("foobar", forKey: "persistedObject")
        let beforeObject = cache.object(forKey: "persistedObject")
        XCTAssertNotNil(beforeObject)

        // Remove all objects from internal NSCache
        // to force reload from disk
        cache.cache.removeAllObjects()

        let afterObject = cache.object(forKey: "persistedObject")
        XCTAssertNotNil(afterObject)
    }

}
