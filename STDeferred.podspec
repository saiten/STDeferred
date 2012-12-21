Pod::Spec.new do |s|
  s.name     = 'STDeferred'
  s.version  = '0.0.3'
  s.license  = { :type => 'New BSD License', :file => 'LICENSE' }
  s.summary  = 'STDeferred is simple implementation of Deferred object.'
  s.homepage = 'http://github.com/saiten/STDeferred'
  s.author   = { 'saiten' => 'saiten@isidesystem.net' }
  s.source   = { :git => 'https://github.com/saiten/STDeferred.git', :tag => '0.0.3' }
  s.requires_arc = true
  s.platform = :ios
  s.source_files = 'STDeferred', 'STDeferred/**/*.{h,m}'
end
