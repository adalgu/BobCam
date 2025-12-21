# Podfile for BobCam iOS Project

# Minimum iOS version
platform :ios, '15.0'

# Use frameworks for all targets
use_frameworks!

# Inhibit warnings from CocoaPods libraries
inhibit_all_warnings!

target 'BobCamAgent' do
  # UI and Development
  pod 'SwiftLint', '~> 0.54'
  
  # Networking (if needed for future features)
  # pod 'Alamofire', '~> 5.8'
  
  # Utilities
  # pod 'SnapKit', '~> 5.6'  # Auto Layout DSL
  
  target 'BobCamAgentTests' do
    inherit! :search_paths
    # Unit testing dependencies
    # pod 'Quick', '~> 7.3'
    # pod 'Nimble', '~> 12.3'
  end

  target 'BobCamAgentUITests' do
    # UI testing dependencies
  end
end

# Post install configuration
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Ensure deployment target consistency
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      
      # Enable module stability
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      
      # Disable bitcode (deprecated in Xcode 14)
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      
      # Code signing
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CODE_SIGNING_IDENTITY[sdk=appletvos*]'] = ''
      config.build_settings['CODE_SIGNING_IDENTITY[sdk=iphoneos*]'] = ''
      config.build_settings['CODE_SIGNING_IDENTITY[sdk=watchos*]'] = ''
    end
  end
end