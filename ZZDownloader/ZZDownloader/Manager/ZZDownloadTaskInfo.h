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

@property (nonatomic) ZZDownloadState state;
@property (nonatomic) ZZDownloadAssignedCommand command;
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *entityType;

@property (nonatomic, strong) NSDictionary *argv;
@property (nonatomic) NSError *lastestError;
@property (nonatomic) int32_t triedCount;

@property (nonatomic) NSMutableArray *sectionsLengthList;
@property (nonatomic) NSMutableArray *sectionsDownloadedList;
@property (nonatomic) NSMutableArray *sectionsContentTime;

- (long long)getTotalLength;
- (long long)getDownloadedLength;
- (CGFloat)getProgress;
- (NSArray *)getSectionsTotalLength;

// used for recover entity
- (ZZDownloadBaseEntity *)recoverEntity;
@end
