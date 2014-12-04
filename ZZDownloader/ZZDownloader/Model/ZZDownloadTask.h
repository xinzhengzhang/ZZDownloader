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
    ZZDownloadTaskErrorTypeInterruptError
};

// MARK: subClass has to implement ZZDownloadParserProtocol
@interface ZZDownloadTask : MTLModel <MTLJSONSerializing>

@property (nonatomic) ZZDownloadState state;
@property (nonatomic) ZZDownloadAssignedCommand command;
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *entityType;

@property (nonatomic, strong) NSDictionary *argv;

@property (nonatomic) NSError *lastestError;

- (void)startWithStartSuccessBlock:(void (^)(void))block;

- (void)pauseWithPauseSuccessBlock:(void (^)(void))block ukeru:(BOOL)ukeru;

- (void)removeWithRemoveSuccessBlock:(void (^)(void))block;

+ (ZZDownloadTask *)buildTaskFromDisk:(NSDictionary *)params;

// used for task info

@property (nonatomic) int32_t triedCount;

- (long long)getTotalLength;
- (long long)getDownloadedLength;
- (CGFloat)getProgress;
- (NSArray *)getSectionsContentTimes;

@property (nonatomic) NSMutableArray *sectionsLengthList;
@property (nonatomic) NSMutableArray *sectionsDownloadedList;
@property (nonatomic) NSMutableArray *sectionsContentTime;

@end
