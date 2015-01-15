//
//  ZZDownloadTaskGroupManager.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/26/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTaskGroup.h"

extern NSString * const ZZDownloadTaskGroupNotifyUiNotification;

@interface ZZDownloadTaskGroupManager : NSObject

+ (id) shared;

- (void)checkAllTaskWithId:(NSString *)aggregationKey withCompletationBlock:(void (^)(ZZDownloadTaskGroup *))block;

- (void)checkAllTaskGroupWithCompletationBlock:(void (^)(NSArray *))block;

@end
