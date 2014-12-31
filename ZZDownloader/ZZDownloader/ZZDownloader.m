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
#import "ZZDownloadTaskManagerV2.h"
#import "ZZDownloadBackgroundSessionManager.h"
@implementation ZZDownloader

+ (void)load
{
    [ZZDownloadTaskManagerV2 shared];
    [ZZDownloadNotifyManager shared];
    [ZZDownloadTaskGroupManager shared];
    [ZZDownloadBackgroundSessionManager shared];
}

@end
