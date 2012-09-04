Pod::Spec.new do |s|
  s.name     = 'STDeferred'
  s.version  = '0.0.1'
  s.license  = 'MIT'
  s.summary  = 'STDeferred is simple implementation of Deferred object.'
  s.homepage = 'http://github.com/saiten/STDeferred'
  s.author   = { 'saiten' => 'saiten@isidesystem.net' }
  s.source   = { :git => 'https://github.com/saiten/STDeferred.git', :tag => '0.0.1' }
  s.platform = :ios
  s.source_files = 'STDeferred/**/*.{h,m}'
  s.preserve_paths = 'Podfile', 'Podfile.lock', 'STDeferredTest', 'Frameworks', 'STDeferred.xcodeproj', 'STDeferred.xcworkspace'
end
