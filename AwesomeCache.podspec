Pod::Spec.new do |s|
  s.name                  = "AwesomeCache"
  s.version               = "2.0"
  s.summary               = "Delightful on-disk cache (written in Swift)"
  s.description           = "Delightful on-disk cache (written in Swift). Backed by NSCache for maximum performance and support for expiry of single objects."
  s.homepage              = "https://github.com/aschuch/AwesomeCache"
  s.license               = { :type => "MIT", :file => "LICENSE" }
  s.author                = { "Alexander Schuch" => "alexander@schuch.me" }
  s.social_media_url      = "http://twitter.com/schuchalexander"
  s.platform              = :ios
  s.ios.deployment_target = "8.0"
  s.source                = { :git => "https://github.com/aschuch/AwesomeCache.git", :tag => s.version }
  s.requires_arc          = true
  s.source_files          = "AwesomeCache/Cache.swift", "AwesomeCache/CacheObject.swift"
end
