//
//  ZZDownloadTaskGroup.h
//  ibiliplayer
//
//  Created by zhangxinzheng on 11/25/14.
//  Copyright (c) 2014 Zhang Rui. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ZZDownloadTaskGroupState) {
    ZZDownloadTaskGroupStateWaiting = 111,
    ZZDownloadTaskGroupStateDownloading,
    ZZDownloadTaskGroupStateDownloaded,
    ZZDownloadTaskGroupStatePaused
};

@interface ZZDownloadTaskGroup : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *coverUrl;
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *realKey;
@property (nonatomic) ZZDownloadTaskGroupState state;
@property (nonatomic) NSMutableDictionary *taskInfoDict;

@end
