#
# Be sure to run `pod lib lint Xocolatl.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Xocolatl"
  s.version          = "0.1.0"
  s.summary          = "OS X http Server"
  s.homepage         = "https://github.com/QuetzalMX"
  s.license          = 'MIT'
  s.author           = { "Fernando" => "fernando.olivares@me.com" }
  s.source           = { :git => "https://github.com/QuetzalMX/Xocolatl.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Core/**/*.{h,m}, Xocolatl/**/*.{h,m}'
  s.resource_bundles = {
    'Xocolatl' => ['Pod/Assets/*.png']
  }

end
