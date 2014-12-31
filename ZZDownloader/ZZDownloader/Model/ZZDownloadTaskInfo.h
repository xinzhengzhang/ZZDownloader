//
//  ZZDownloadTaskInfo.h
//  Pods
//
//  Created by zhangxinzheng on 11/20/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTask.h"
#import "ZZDownloadBaseEntity.h"
@interface ZZDownloadTaskInfo : NSObject

@property (atomic) ZZDownloadState state;
@property (atomic) ZZDownloadState lastestState;
@property (atomic) ZZDownloadAssignedCommand command;
@property (atomic) NSString *key;
@property (atomic) NSString *entityType;

//@property (atomic) NSDictionary *argv;
@property (atomic) NSError *lastestError;
@property (atomic) int32_t triedCount;

//used for ui
@property (atomic) NSInteger index;

@property (atomic) NSArray *sectionsLengthList;
@property (atomic) NSArray *sectionsDownloadedList;
@property (atomic) NSArray *sectionsContentTime;

- (void)updateSelfByArgv:(NSDictionary *)argv;
//- (ZZDownloadTaskInfo *)deepCopy;

- (long long)getTotalLength;
- (long long)getDownloadedLength;
- (CGFloat)getProgress;
- (NSArray *)getSectionsTotalLength;

// used for recover entity
- (ZZDownloadBaseEntity *)recoverEntity;

- (NSString *)getUILabelText;

// 0 nothing(invalid button)
// 1 start command
// 2 pause command
// 3 play command
- (int8_t)getPressedCommand;
- (BOOL)isDownloaded;
- (BOOL)allowRemove;
- (BOOL)isPostiveState;

@end
