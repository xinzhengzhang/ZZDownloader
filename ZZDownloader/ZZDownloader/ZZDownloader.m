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
        [[ZZDownloadManager shared] startEpTaskWithEpId:@"124"];
        [[ZZDownloadManager shared] startEpTaskWithEpId:@"125"];
        [[ZZDownloadManager shared] startEpTaskWithEpId:@"126"];
        [[ZZDownloadManager shared] startEpTaskWithEpId:@"127"];
    
    
    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"123"];
    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"124"];
    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"125"];
    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"126"];
    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"127"];
    [[ZZDownloadManager shared] pauseEpTaskWithEpId:@"123"];
}

@end
