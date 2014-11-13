//
//  ZZDownloadNotifyQueue.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadNotifyQueue.h"

@implementation ZZDownloadNotifyQueue

+ (id)shared
{
    static ZZDownloadNotifyQueue *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadNotifyQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
    });
    return queue;
}

@end
