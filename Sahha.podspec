Pod::Spec.new do |s|
  s.name             = 'Sahha'
  s.version          = '1.4.0-beta.2'
  s.summary          = 'Sahha Swift SDK for iOS'
  s.homepage         = 'https://sahha.ai'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Sahha' => 'developer@sahha.ai' }
  s.source           = { :git => 'https://github.com/sahha-ai/sahha-ios.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_versions = ['5.5', '6.0']
  s.source_files = 'Sources/Sahha/**/*'
end

