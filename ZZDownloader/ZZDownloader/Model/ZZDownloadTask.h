//
//  ZZTask.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

typedef NS_ENUM(NSUInteger, ZZDownloadState) {
    ZZDownloadStateWaiting = 1234,
    ZZDownloadStateDownloading,
    ZZDownloadStatePaused,
    ZZDownloadStateDownloaded,
    ZZDownloadStateFail,
    ZZDownloadStateInvalid
};

typedef NS_ENUM(NSUInteger, ZZDownloadAssignedCommand) {
    ZZDownloadAssignedCommandNone,
    ZZDownloadAssignedCommandPause,
    ZZDownloadAssignedCommandRemove,
    ZZDownloadAssignedCommandStart
};

// MARK: subClass has to implement ZZDownloadParserProtocol
@interface ZZDownloadTask : MTLModel <MTLJSONSerializing>

@property (nonatomic) ZZDownloadState state;
@property (nonatomic) ZZDownloadAssignedCommand command;
@property (nonatomic) NSString *key;

@property (nonatomic, strong) NSDictionary *params;

- (void)startWithStartSuccessBlock:(void (^)(void))block;

- (void)pauseWithPauseSuccessBlock:(void (^)(void))block;

- (void)removeWithRemoveSuccessBlock:(void (^)(void))block;

+ (ZZDownloadTask *)buildTaskFromDisk:(NSDictionary *)params;

// used for task info
- (float)getProgress;

@end
