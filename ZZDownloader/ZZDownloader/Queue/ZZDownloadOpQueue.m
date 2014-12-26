//
//  ZZDownloadOpQueue.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadOpQueue.h"

@implementation ZZDownloadOpQueue

+ (id)shared
{
    static ZZDownloadOpQueue *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadOpQueue alloc] init];
        queue.name = ZZDownloadOpQueueName;
        queue.maxConcurrentOperationCount = 1;
    });
    return queue;
}

@end
