//
//  ZZDownloadTaskManagerV2.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 12/15/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZZDownloadOperation.h"
#import "ZZDownloadBaseEntity.h"

#define ZZDownloadTaskManagerTaskDir @".Downloads/zzdownloadtaskmanagertask"
#define ZZDownloadTaskManagerTaskFileDir @".Downloads/zzdownloadtaskmanagertaskfile"
#define ZZDownloadTaskManagerTaskFileDirTmp @".Downloads/zzdownloadtaskmanagertaskfiletmp"

@interface ZZDownloadTaskManagerV2 : NSObject

@property (nonatomic) BOOL enableDownloadUnderWWAN;
+ (id)shared;
+ (NSString *)downloadFolder;

- (void)addOp:(ZZDownloadOperation *)operation withEntity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block;
- (BOOL)isDownloading;
- (void)checkSelfUnSecheduledWorkKey:(NSString *)key block:(void(^)(id))block;
@end
