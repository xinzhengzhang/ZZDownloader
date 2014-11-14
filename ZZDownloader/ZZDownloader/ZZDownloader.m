//
//  ZZDownloader.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/12/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloader.h"
#import "ZZDownloadManager.h"
@implementation ZZDownloader

+ (void)dosth
{
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"123"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"123"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"123"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"234"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"423"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"123"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"153"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"123"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"143"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"143"];
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"423"];

}

@end
