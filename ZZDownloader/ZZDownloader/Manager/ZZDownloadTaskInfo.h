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
@interface ZZDownloadTaskInfo : NSObject <NSCopying>

@property (nonatomic) ZZDownloadState state;
@property (nonatomic) ZZDownloadState lastestState;
@property (nonatomic) ZZDownloadAssignedCommand command;
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *entityType;

@property (nonatomic, strong) NSDictionary *argv;
@property (nonatomic) NSError *lastestError;
@property (nonatomic) int32_t triedCount;

//used for ui
@property (nonatomic) NSInteger index;

@property (nonatomic) NSArray *sectionsLengthList;
@property (nonatomic) NSArray *sectionsDownloadedList;
@property (nonatomic) NSArray *sectionsContentTime;

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
