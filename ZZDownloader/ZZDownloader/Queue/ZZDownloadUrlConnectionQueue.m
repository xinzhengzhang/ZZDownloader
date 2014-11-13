//
//  ZZDownloadUrlConnectionQueue.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadUrlConnectionQueue.h"

@implementation ZZDownloadUrlConnectionQueue

+ (id)shared
{
    static ZZDownloadUrlConnectionQueue *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadUrlConnectionQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
    });
    return queue;
}

@end
