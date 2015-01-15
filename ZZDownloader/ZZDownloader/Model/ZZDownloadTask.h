//
//  ZZTask.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "ZZDownloadBaseEntity.h"


@class ZZDownloadBaseEntity;

typedef NS_ENUM(NSUInteger, ZZDownloadState) {
    ZZDownloadStateNothing = 1234,
    ZZDownloadStateWaiting,
    ZZDownloadStateDownloading,
    ZZDownloadStateRealPaused,
    ZZDownloadStateInterrputPaused,
    ZZDownloadStateDownloaded,
    ZZDownloadStateFail,
    ZZDownloadStateInvalid,
    ZZDownloadStateRemoved,
    ZZDownloadStateDownloadingDanmaku,
    ZZDownloadStateDownloadingCover,
    ZZDownloadStateParsing
};

typedef NS_ENUM(NSUInteger, ZZDownloadAssignedCommand) {
    ZZDownloadAssignedCommandNone,
    ZZDownloadAssignedCommandPause,
    ZZDownloadAssignedCommandRemove,
    ZZDownloadAssignedCommandStart,
    ZZDownloadAssignedCommandInterruptPaused
};

extern NSString * const ZZDownloadTaskErrorDomain;

typedef NS_ENUM(NSUInteger, ZZDownloadTaskErrorType) {
    ZZDownloadTaskErrorTypeHttpError = 444,
    ZZDownloadTaskErrorTypeTransferError,
    ZZDownloadTaskErrorTypeIOError,
    ZZDownloadTaskErrorTypeInterruptError,
    ZZDownloadTaskErrorTypeIOFullError
};

typedef NS_ENUM(NSUInteger, ZZDownloadTaskArrangeType) {
    ZZDownloadTaskArrangeTypeUnArranged = 0,
    ZZDownloadTaskArrangeTypeCFSync
};

// MARK: subClass has to implement ZZDownloadParserProtocol
@interface ZZDownloadTask : MTLModel <MTLJSONSerializing>

@property (atomic) ZZDownloadState state;
@property (atomic) ZZDownloadAssignedCommand command;
@property (atomic) NSString *key;
@property (atomic) NSString *entityType;

@property (atomic) ZZDownloadTaskArrangeType taskArrangeType;
@property (atomic) int32_t weight;

@property (atomic) NSDictionary *argv;

@property (atomic) NSError *lastestError;


- (void)startWithStartSuccessBlock:(void (^)(void))block;

- (void)pauseWithPauseSuccessBlock:(void (^)(void))block ukeru:(BOOL)ukeru;

- (void)removeWithRemoveSuccessBlock:(void (^)(void))block;

+ (ZZDownloadTask *)buildTaskFromDisk:(NSDictionary *)params;

- (ZZDownloadBaseEntity *)recoverEntity;

- (ZZDownloadTask *)deepCopy;
// used for task info

@property (nonatomic) int32_t triedCount;

- (long long)getTotalLength;
- (long long)getDownloadedLength;
- (float)getProgress;
- (NSArray *)getSectionsContentTimes;

@property (atomic) NSMutableArray *sectionsLengthList;
@property (atomic) NSMutableArray *sectionsDownloadedList;
@property (atomic) NSMutableArray *sectionsContentTime;

@end
