//
//  ZZDownloadTaskGroup.h
//  ibiliplayer
//
//  Created by zhangxinzheng on 11/25/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ZZDownloadTaskGroupState) {
    ZZDownloadTaskGroupStateWaiting = 111,
    ZZDownloadTaskGroupStateDownloading,
    ZZDownloadTaskGroupStateDownloaded,
    ZZDownloadTaskGroupStatePaused
};

@interface ZZDownloadTaskGroup : NSObject

@property (atomic) NSString *title;
@property (atomic) NSString *coverUrl;
@property (atomic) NSString *key;
@property (atomic) NSString *realKey;
@property (atomic) ZZDownloadTaskGroupState state;
@property (atomic) NSInteger totalCount;
@property (atomic) int32_t downloadedCount;
@property (atomic) int32_t runningCount;
@property (atomic) int32_t watingCount;

@property (atomic) NSMutableDictionary *taskInfoDict;

@property (atomic) int32_t index;
@property (atomic) BOOL willRemove;
@end
