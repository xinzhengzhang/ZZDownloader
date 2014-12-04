//
//  ZZDownloadTaskManager.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTask.h"
#import "ZZDownloadOperation.h"

#import "ZZDownloadBaseEntity.h"

@interface ZZDownloadTaskManager : NSObject

//default is no
@property (nonatomic) BOOL enableDownloadUnderWWAN;
+ (id)shared;
+ (NSArray *)getBiliTaskFilePathList;
+ (NSString *)downloadFolder;
- (void)addOp:(ZZDownloadOperation *)operation withEntity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block;
- (BOOL)isDownloading;

@end
