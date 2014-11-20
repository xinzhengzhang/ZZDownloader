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

@property (nonatomic) int32_t triedCount;

@property (nonatomic) NSMutableArray *sectionsLengthList;
@property (nonatomic) NSMutableArray *sectionsDownloadedList;

- (long long)getTotalLength;
- (long long)getDownloadedLength;
- (CGFloat)getProgress;

// used for recover entity
- (ZZDownloadBaseEntity *)recoverEntity;
@end
