//
//  ZZDownloadUrlConnectionQueue.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>

#define ZZDownloadUrlConnectionQueueName @"ZZDownloadUrlConnectionQueueName"

@interface ZZDownloadUrlConnectionQueue : NSOperationQueue
+ (id) shared;
@end
