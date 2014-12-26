//
//  ZZDownloadNotifyQueue.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>

#define ZZDownloadNotifyQueueName @"ZZDownloadNotifyQueueName"

@interface ZZDownloadNotifyQueue : NSOperationQueue
+ (id) shared;
@end
