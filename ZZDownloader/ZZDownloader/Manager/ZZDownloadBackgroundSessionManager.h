//
//  ZZDownloadBackgroundSessionManager.h
//  ZZDownloder
//
//  Created by zhangxinzheng on 12/18/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "AFURLSessionManager.h"
#import "ZZDownloadTask.h"

@interface ZZDownloadBackgroundSessionManager : AFURLSessionManager

+ (id)shared;
- (void)addCacheTaskByTasks:(NSArray *)tasks completionBlock:(void (^)(NSNumber *))block;
- (void)removeCacheTaskByTask:(ZZDownloadTask *)task section:(int32_t)section typeTag:(NSString *)typeTag;
- (void)checkSelf;

@end
