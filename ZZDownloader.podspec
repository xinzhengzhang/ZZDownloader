Pod::Spec.new do |s|
  s.name           = 'ZZDownloader'
  s.version        = '0.0.1'
  s.summary        = "ZZDownloader"
  s.homepage       = "https://github.com/xinzhengzhang/ZZDownloader"
  s.source         = { :git => "https://github.com/xinzhengzhang/ZZDownloader.git", :tag => "0.0.2"}
  s.author         = { 'zxz' => 'zhangxzheng@gmail.com' }
  s.ios.deployment_target = '6.0'
  s.requires_arc   = true
  s.source_files   = 'ZZDownloader/ZZDownloader/*.{h,m}'

  s.subspec 'Bili' do |ss|
	ss.source_files= 'ZZDownloader/ZZDownloader/Bili/*.{h,m}'
  end

  s.subspec 'Manager' do |ss|
	ss.source_files = 'ZZDownloader/ZZDownloader/Manager/*.{h,m}'
  end

  s.subspec 'Model' do |ss|
	ss.source_files = 'ZZDownloader/ZZDownloader/Model/*.{h,m}'
  end

  s.subspec 'Parser' do |ss|
	ss.source_files = 'ZZDownloader/ZZDownloader/Parser/*.{h,m}'
  end

   s.subspec 'Queue' do |ss|
	ss.source_files = 'ZZDownloader/ZZDownloader/Queue/*.{h,m}'
  end
   
  s.subspec 'Operation' do |ss|
	ss.source_files = 'ZZDownloader/ZZDownloader/Operation/*.{h,m}'
  end

 s.public_header_files = 'ZZDownloader/ZZDownloader/*.h'
  
  s.license      = { :type => 'Apache License, Version 2.0', :text => <<-LICENSE
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    LICENSE
  }  
  s.dependency   'AFDownloadRequestOperation'
  s.dependency   'Mantle'
  s.dependency   'libextobjc'
  s.dependency   'SVProgressHUD'
end
