Pod::Spec.new do |s|
  s.name             = "Xocolatl"
  s.version          = "0.1.0"
  s.summary          = "OS X http Server"
  s.homepage         = "https://github.com/QuetzalMX"
  s.license          = 'MIT'
  s.author           = { "Fernando" => "fernando.olivares@me.com" }
  s.source           = { :git => "https://github.com/QuetzalMX/Xocolatl.git", :tag => s.version.to_s }

  s.platform      = :osx, '10.10'
  s.requires_arc = true

s.source_files = 'Core/**/*.{h,m}', 'Xocolatl/**/*.{h,m}', 'XocolatlFramework/**/*.{h,m}'
  s.resource_bundles = {
    'Xocolatl' => ['Pod/Assets/*.png']
  }

end
