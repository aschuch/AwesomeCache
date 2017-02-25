# Awesome Cache

[![Build Status](https://travis-ci.org/aschuch/AwesomeCache.svg)](https://travis-ci.org/aschuch/AwesomeCache)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/AwesomeCache.svg)](https://img.shields.io/cocoapods/v/AwesomeCache.svg)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)
![Swift 3.0](https://img.shields.io/badge/Swift-3.0-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey.svg)

Delightful on-disk cache (written in Swift).
Backed by NSCache for maximum performance and support for expiry of single objects.


## Usage

```swift
do {
    let cache = try Cache<NSString>(name: "awesomeCache")

    cache["name"] = "Alex"
    let name = cache["name"]
    cache["name"] = nil
} catch _ {
    print("Something went wrong :(")
}
```

### Sync by design

AwesomeCache >= 3.0 is designed to have a sync API, making it easy to reason about the actual contents of the cache. This decision has been made based on [feedback from the community](issues/33), to keep the API of AwesomeCache small and easy to use. 

The internals of the cache use a concurrent dispatch queue, that syncs reads and writes for thread safety. In case a particular caching operation blocks your main thread for too long, consider offloading the read and write operations to a different thread.

```swift
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
	cache["name"] = "Alex"
}
```

### Cache expiry

Objects can also be cached for a certain period of time.

```swift
cache.setObject("Alex", forKey: "name", expires: .never) // same as cache["name"] = "Alex"
cache.setObject("Alex", forKey: "name", expires: .seconds(2)) // name expires in 2 seconds
cache.setObject("Alex", forKey: "name", expires: .date(Date(timeIntervalSince1970: 1428364800))) // name expires on 4th of July 2015
```

If an object is accessed after its expiry date, it is automatically removed from the cache and deleted from disk.
However, you are responsible to delete expired objects regularly by calling `removeExpiredObjects` (e.g. on app launch).

### Awesome API Caching

API responses are usually cached for a specific period of time. AwesomeCache provides an easy method to cache a block of asynchronous tasks.

```swift
cache.setObject(forKey: "name", cacheBlock: { success, failure in
  // Perform tasks, e.g. call an API
  let response = ...

  success(response, .seconds(300)) // Cache response for 5 minutes
  // ... or failure(error)
}, completion: { object, isLoadedFromCache, error in
	if object {
	 	// object is now cached
	}
})
```

If the cache already contains an object, the `completion` block is called with the cached object immediately.

If no object is found or the cached object is already expired, the `cacheBlock` is called.
You may perform any tasks (e.g. network calls) within this block. Upon completion of these tasks, make sure to call the `success` or `failure` block that is passed to the `cacheBlock`. The cacheBlock will not be re-evaluated until the object is expired or manually deleted.

The completion block is invoked as soon as the cacheBlock is finished and the object is cached.

## Version Compatibility

Current Swift compatibility breakdown:

| Swift Version | Framework Version |
| ------------- | ----------------- |
| 3.0           | 5.x               |
| 2.3           | 4.x               |
| 2.2           | 3.x               |

[all releases]: https://github.com/aschuch/AwesomeCache/releases

## Installation

#### Carthage

Add the following line to your [Cartfile](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile).

```
github "aschuch/AwesomeCache"
```

Then run `carthage update`.

#### CocoaPods

Add the following line to your Podfile.

```
pod "AwesomeCache", "~> 3.0"
```

Then run `pod install` with CocoaPods 0.36 or newer.

#### Manually

Just drag and drop the two `.swift` files as well as the `NSKeyedUnarchiverWrapper.h/.m` files in the `AwesomeCache` folder into your project.
If you are adding AwesomeCache to a Swift project, you also need to add an import for `NSKeyedUnarchiverWrapper.h` to your bridging header.

## Tests

Open the Xcode project and press `⌘-U` to run the tests.

Alternatively, all tests can be run in the terminal using [xctool](https://github.com/facebook/xctool).

```bash
xctool -scheme AwesomeCacheTests -sdk iphonesimulator test
```

## Contributing

* Create something awesome, make the code better, add some functionality,
  whatever (this is the hardest part).
* [Fork it](http://help.github.com/forking/)
* Create new branch to make your changes
* Commit all your changes to your branch
* Submit a [pull request](http://help.github.com/pull-requests/)


## Contact

Feel free to get in touch.

* Website: <http://schuch.me>
* Twitter: [@schuchalexander](http://twitter.com/schuchalexander)
