//
//  ZZDownloader.m
//  ibiliplayer
//
//  Created by zhangxinzheng on 12/1/14.
//  Copyright (c) 2014 Zhang Rui. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZZDownloader.h"
#import "ZZDownloadTaskManager.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadTaskGroupManager.h"
#import "BiliPlayerConfig.h"

@implementation ZZDownloader

+ (void)load
{
    [ZZDownloadTaskManager shared];
    [[ZZDownloadTaskManager shared] setEnableDownloadUnderWWAN:[BiliPlayerConfig sharedConfig].use3G];
    [ZZDownloadNotifyManager shared];
    [ZZDownloadTaskGroupManager shared];
}

@end
