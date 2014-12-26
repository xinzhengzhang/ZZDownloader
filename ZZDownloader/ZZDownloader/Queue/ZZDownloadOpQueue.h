//
//  ZZDownloadOpQueue.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>

#define ZZDownloadOpQueueName @"ZZDownloadOpQueue"

@interface ZZDownloadOpQueue : NSOperationQueue
+ (id) shared;
@end
