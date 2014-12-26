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

@interface ZZDownloadTaskGroup : NSObject <NSCopying>

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *coverUrl;
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *realKey;
@property (nonatomic) ZZDownloadTaskGroupState state;
@property (nonatomic) NSInteger totalCount;
@property (nonatomic) int32_t downloadedCount;
@property (nonatomic) int32_t runningCount;
@property (nonatomic) int32_t watingCount;

 @property (nonatomic) NSMutableDictionary *taskInfoDict;

@property (nonatomic) int32_t index;

@end
