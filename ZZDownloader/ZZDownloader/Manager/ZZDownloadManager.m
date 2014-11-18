//
//  ZZDownloadManager.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "ZZDownloadManager.h"
#import "BiliDownloadEpEntity.h"
#import "ZZDownloadOperation.h"
#import <Mantle/Mantle.h>
#import "ZZDownloadTaskManager.h"

@implementation ZZDownloadManager

+ (id)shared
{
    static ZZDownloadManager *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadManager alloc] init];
    });
    return queue;
}

- (void)startEpTaskWithEpId:(NSString *)ep_id
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
 
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandStart;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity];
}

- (void)pauseEpTaskWithEpId:(NSString *)ep_id
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandStop;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity];
}

- (void)removeEpTaskWithEpId:(NSString *)ep_id
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandRemove;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity];
}

- (void)checkEpTaskWithEpId:(NSString *)ep_id
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandCheck;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity];
}

@end
