//
//  ZZDownloadManager.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "BiliDownloadManager.h"
#import "ZZDownloadOperation.h"
#import <Mantle/Mantle.h>

@implementation BiliDownloadManager

+ (id)shared
{
    static BiliDownloadManager *share;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[BiliDownloadManager alloc] init];
        [ZZDownloadTaskGroupManager shared];
    });
    return share;
}

- (void)startEpTaskWithEpId:(NSString *)ep_id
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandStart;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity block:nil];
}

- (void)pauseEpTaskWithEpId:(NSString *)ep_id
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandStop;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity block:nil];
}

- (void)removeEpTaskWithEpId:(NSString *)ep_id
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandRemove;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity block:nil];
}

- (void)checkEpTaskWithEpId:(NSString *)ep_id withCompletationBlock:(void (^)(ZZDownloadTaskInfo *))block
{
    BiliDownloadEpEntity *epEntity = [[BiliDownloadEpEntity alloc] init];
    epEntity.ep_id = ep_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandCheck;
    operation.key = [epEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:epEntity block:block];
}

- (void)startAVTaskWithAvId:(BiliDownloadAVEntity *)avEntity
{
    if (!avEntity.av_id) {
        return;
    }
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandStart;
    operation.key = [avEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:avEntity block:nil];
}

- (void)pauseAVTaskWithAvId:(NSString *)av_id page:(int32_t)page
{
    BiliDownloadAVEntity *avEntity= [[BiliDownloadAVEntity alloc] init];
    avEntity.av_id= av_id;
    avEntity.page = page;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandStop;
    operation.key = [avEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:avEntity block:nil];
}

- (void)removeAVTaskWithAvId:(NSString *)av_id page:(int32_t)page
{
    BiliDownloadAVEntity *avEntity= [[BiliDownloadAVEntity alloc] init];
    avEntity.av_id= av_id;
    avEntity.page = page;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandRemove;
    operation.key = [avEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:avEntity block:nil];

}

- (void)checkAVTaskWithAvId:(NSString *)av_id page:(int32_t)page withCompletationBlock:(void (^)(ZZDownloadTaskInfo *))block
{
    BiliDownloadAVEntity *avEntity= [[BiliDownloadAVEntity alloc] init];
    avEntity.av_id= av_id;
    avEntity.page = page;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandCheck;
    operation.key = [avEntity entityKey];
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:avEntity block:block];

}

- (void)checkAvGrouoWithAvId:(NSString *)av_id withCompletationBlock:(void (^)(BiliDownloadAvGroup *))block
{
    BiliDownloadAVEntity *avEntity = [[BiliDownloadAVEntity alloc] init];
    avEntity.av_id = av_id;
    
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandCheckGroup;
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:avEntity block:block];
}

- (void)resumeAllTask
{
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandResumeAll;
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:nil block:nil];
}

- (void)pauseAllTask
{
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command = ZZDownloadCommandPauseAll;
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:nil block:nil];
}

- (void)checkAllGroupWithCompletationBlock:(void (^)(NSArray *))block
{
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command  = ZZDownloadCommandCheckAllGroup;
    
    [[ZZDownloadTaskManager shared] addOp:operation withEntity:nil block:block];
}

@end
