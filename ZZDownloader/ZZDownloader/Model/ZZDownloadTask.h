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
    ZZDownloadStateNothing = 1234,
    ZZDownloadStateWaiting,
    ZZDownloadStateDownloading,
    ZZDownloadStatePaused,
    ZZDownloadStateDownloaded,
    ZZDownloadStateFail,
    ZZDownloadStateInvalid,
    ZZDownloadStateRemoved
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
@property (nonatomic) NSString *entityType;

@property (nonatomic, strong) NSDictionary *argv;

- (void)startWithStartSuccessBlock:(void (^)(void))block;

- (void)pauseWithPauseSuccessBlock:(void (^)(void))block;

- (void)removeWithRemoveSuccessBlock:(void (^)(void))block;

+ (ZZDownloadTask *)buildTaskFromDisk:(NSDictionary *)params;

// used for task info

@property (nonatomic ) int32_t triedCount;
@property (nonatomic) float progress;
//@property (nonatomic, readwrite) int32_t sectionCount;


@end
