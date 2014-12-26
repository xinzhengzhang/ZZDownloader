//
//  ZZDownloadManager.h
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTaskInfo.h"
#import "BiliDownloadEpEntity.h"
#import "BiliDownloadAVEntity.h"
#import "BiliDownloadAvGroup.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadTaskGroupManager.h"
#import "ZZDownloadTaskManager.h"
#import "ZZDownloadTaskManagerV2.h"

@interface BiliDownloadManager : NSObject

+ (id)shared;

- (void)startEpTaskWithEpId:(NSString *)ep_id;
- (void)pauseEpTaskWithEpId:(NSString *)ep_id;
- (void)removeEpTaskWithEpId:(NSString *)ep_id;
- (void)checkEpTaskWithEpId:(NSString *)ep_id withCompletationBlock:(void (^)(ZZDownloadTaskInfo *))block;


- (void)startAVTaskWithAvId:(BiliDownloadAVEntity *)avEntity;
- (void)pauseAVTaskWithAvId:(NSString *)av_id page:(int32_t)page;
- (void)removeAVTaskWithAvId:(NSString *)av_id page:(int32_t)page;
- (void)checkAVTaskWithAvId:(NSString *)av_id page:(int32_t)page withCompletationBlock:(void (^)(ZZDownloadTaskInfo *))block;
- (void)checkAvGrouoWithAvId:(NSString *)av_id withCompletationBlock:(void (^)(BiliDownloadAvGroup *))block;

- (void)resumeAllTask;
- (void)pauseAllTask;

// NSArray: [BiliDownloadAvGroup,]
- (void)checkAllGroupWithCompletationBlock:(void (^)(NSArray *))block;



@end
