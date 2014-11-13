Pod::Spec.new do |s|
  s.name           = 'ZZDownloader'
  s.version        = '0.0.1'
  s.summary        = "ZZDownloader"
  s.homepage       = "https://github.com/xinzhengzhang/ZZDownloader"
  s.source         = { :git => "https://github.com/xinzhengzhang/ZZDownloader"}
  s.author         = { 'zxz' => 'zhangxzheng@gmail.com' }
  s.ios.deployment_target = '6.0'
  s.requires_arc   = true
  s.source_files   = 'ZZDownloader/*.{h,m}'
  s.license        = 'MIT'
  s.dependency   'AFDownloadRequestOperation'
  s.dependency   'Mantle'
end
