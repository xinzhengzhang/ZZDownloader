//
//  ZZDownloader.m
//  ibiliplayer
//
//  Created by zhangxinzheng on 12/1/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZZDownloader.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadTaskGroupManager.h"
//#import "BiliPlayerConfig.h"
//#import "VideoDownloadToZZDownload.h"
#import "ZZDownloadTaskManagerV2.h"
#import "ZZDownloadBackgroundSessionManager.h"
@implementation ZZDownloader

+ (void)load
{
//    [VideoDownloadToZZDownload updateDownloadTask];
    [ZZDownloadTaskManagerV2 shared];
//    [[ZZDownloadTaskManagerV2 shared] setEnableDownloadUnderWWAN:[BiliPlayerConfig sharedConfig].use3G];
    [ZZDownloadNotifyManager shared];
    [ZZDownloadTaskGroupManager shared];
    [ZZDownloadBackgroundSessionManager shared];
}

@end
