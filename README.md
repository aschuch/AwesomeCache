# Awesome Cache

[![Build Status](https://travis-ci.org/aschuch/AwesomeCache.svg)](https://travis-ci.org/aschuch/AwesomeCache)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)

Delightful on-disk cache (written in Swift).
Backed by NSCache for maximum performance and support for expiry of single objects.


## Usage

```swift
let cache = Cache<NSString>(name: "awesomeCache")

cache["name"] = "Alex"
let name = cache["name"]
cache["name"] = nil
```

### Cache expiry

Objects can also be cached for a certain period of time.

```swift
cache.setObject("Alex", forKey: "name", expires: .Never) // same as cache["name"] = "Alex"
cache.setObject("Alex", forKey: "name", expires: .Seconds(2)) // name expires in 2 seconds
cache.setObject("Alex", forKey: "name", expires: .Date(NSDate(timeIntervalSince1970: 1428364800))) // name expires on 4th of July 2015
```

If an object is accessed after its expiry date, it is automatically removed from the cache and deleted from disk.
However, you are responsible to delete expired objects regularily by calling `removeExpiredObjects` (e.g. on app launch).


### Awesome API Caching

API responses are usually cached for a specific period of time. AwesomeCache provides an easy method to cache a block of asynchronous tasks.

```swift
cache.setObjectForKey("name", cacheBlock: { success, failure in
  // Perform tasks, e.g. call an API
  let response = ...

  success(response, .Seconds(300)) // Cache response for 5 minutes
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


## Installation

The master branch of AwesomeCache is ready for swift 1.2. In case you are still on 1.1, please refer to the `swift-1.1` tag.

#### Carthage

Add the following line to your [Cartfile](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile).

```
github "aschuch/AwesomeCache"
```

Then run `carthage update`.

#### Cocoapods

**NOTE:** Cocoapods does not officially support Swift projects yet.  Make sure you have Cocoapods 0.36 beta installed by running `gem install cocoapods --pre`.

Add the following line to your Podfile.

```
pod "AwesomeCache", "~> 1.0"
```

Then run `pod install` with Cocoapods 0.36 or newer.

#### Manually

Just drag and drop the two `.swift` files in the `AwesomeCache` folder into your project.

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
