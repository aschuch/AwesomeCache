Pod::Spec.new do |s|
  s.name                  = "AwesomeCache-hwh"
  s.version               = "2.0"
  s.summary               = "轻量级本地缓存swift 库"
  s.description           = "轻量级本地缓存swift 库. Backed by NSCache for maximum performance and support for expiry of single objects."
  s.homepage              = "https://github.com/huang1988519/"
  s.license               = { :type => "MIT", :file => "LICENSE" }
  s.author                = { "huangwh" => "huang1988519@126.com" }
  s.social_media_url      = "http://huang1988519.github.io/"
  s.platform              = :ios
  s.ios.deployment_target = "8.0"
  s.source                = { :git => "https://github.com/huang1988519/AwesomeCache.git", :tag => s.version }
  s.requires_arc          = true
  s.source_files          = "AwesomeCache/Cache.swift", "AwesomeCache/CacheObject.swift"
end
