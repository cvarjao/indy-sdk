#
#  Be sure to run `pod spec lint libindy.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#
Pod::Spec.new do |s|
  s.name         = "libindy"
  s.version      = "1.16.0"
  s.summary      = "A short description of libindy."
  s.description  = <<-DESC
  libindy pod
  DESC
  s.homepage = "https://github.com/hyperledger/indy-sdk"
  s.license = { :type => 'Apache 2.0' }
  s.author = { "Clécio Varjão" => "1348549+cvarjao@users.noreply.github.com" }
  s.platform = :ios, "10.0"
  s.ios.deployment_target = "10.0"
  s.source = { :http => 'file:' + File.expand_path('../../', __dir__) + '/libindy/target/libindy.zip', :type => 'zip'}
  #s.preserve_paths = "**/*.{h,a,m,plist}"
  s.module_name = "libindy"
  s.ios.vendored_frameworks = "Frameworks/libindy.xcframework"
  s.source_files = "Frameworks/libindy.xcframework/ios-arm64/Headers/*.{h}"
  #s.xcconfig = { 'LIBRARY_SEARCH_PATHS' => '$(PODS_ROOT)/libindy/Frameworks/libindy.xcframework/ios-arm64_x86_64-simulator'}
  #s.vendored_libraries = "Frameworks/libindy.xcframework/ios-arm64_x86_64-simulator/*.a"
  s.requires_arc  = true
  s.static_framework = true
end
