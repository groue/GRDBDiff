Pod::Spec.new do |s|
  s.name     = 'GRDBDiff'
  s.version  = '0.1.0'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'Diff algorithms for SQLite, based on GRDB.'
  s.homepage = 'https://github.com/groue/GRDBDiff'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/groue/GRDBDiff.git', :tag => "v#{s.version}" }
  s.module_name = 'GRDBDiff'
  
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '2.0'
  
  s.default_subspec = 'default'
  
  s.subspec 'default' do |ss|
    ss.source_files = 'Sources/**/*.{h,swift}'
    ss.dependency "GRDB.swift", "~> 3.5"
  end
  
  s.subspec 'GRDBCipher' do |ss|
    ss.source_files = 'Sources/**/*.{h,swift}'
    ss.dependency "GRDBCipher", "~> 3.5"
    ss.xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
      'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
    }
  end
end
