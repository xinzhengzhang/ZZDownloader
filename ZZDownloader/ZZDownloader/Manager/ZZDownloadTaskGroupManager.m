//
//  BiliDownloadTaskGroupManager.m
//  ibiliplayer
//
//  Created by zhangxinzheng on 11/26/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloadTaskGroupManager.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadTaskInfo.h"
#import <sys/time.h>

#define BiliDownloadValidGroupTask @[@"BiliDownloadAvGroup"]

NSString * const ZZDownloadTaskGroupNotifyUiNotification = @"ZZDownloadTaskGroupNotifyUiNotification";

@interface ZZDownloadTaskGroupManager (){
    struct timeval container;
}

@property (nonatomic) NSMutableDictionary *allTaskGroupInfo;
@property (nonatomic, strong) NSMutableDictionary *allTaskNotificationTimeDict;
//@property (nonatomic) dispatch_queue_t managerQueue;

@end

@implementation ZZDownloadTaskGroupManager

+ (id)shared
{
    static ZZDownloadTaskGroupManager *share;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[ZZDownloadTaskGroupManager alloc] init];
        share.allTaskGroupInfo = [NSMutableDictionary dictionary];
        //        share.managerQueue = dispatch_queue_create("com.zzdownloader.bilitaskgroupmanager.groupmanager.queue", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:share selector:@selector(notifyReceived:) name:ZZDownloadTaskNotifyUiNotification object:nil];
    });
    return share;
}

- (void)checkAllTaskWithId:(NSString *)aggregationKey withCompletationBlock:(void (^)(ZZDownloadTaskGroup *))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        ZZDownloadTaskGroup *group = self.allTaskGroupInfo[aggregationKey];
        block(group);
    });
}

- (void)checkAllTaskGroupWithCompletationBlock:(void (^)(NSArray *))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        block([self.allTaskGroupInfo allValues]);
    });
}

- (void)notifyReceived:(NSNotification *)aNotification
{
    NSAssert([NSThread isMainThread],@"ZZDownloadTaskGroupManager assert");
    
    ZZDownloadTaskInfo *taskInfo = aNotification.object;
    if (!taskInfo) {
        return;
    }
    //    dispatch_async(dispatch_get_main_queue(), ^{
    [self dealTaskInfo:taskInfo];
    //    });
}

- (void)dealTaskInfo:(ZZDownloadTaskInfo *)taskInfo
{
    NSAssert([NSThread isMainThread],@"ZZDownloadTaskGroupManager assert");
    if (!taskInfo) {
        return;
    }
    ZZDownloadBaseEntity *entity = [taskInfo recoverEntity];
    NSString *aggregationKey = [entity aggregationKey];
    __block ZZDownloadTaskGroup *group = self.allTaskGroupInfo[aggregationKey];
    
    if (!group) {
        NSString *type = [entity aggregationType];
        if ([BiliDownloadValidGroupTask containsObject:type]) {
            Class class = NSClassFromString(type);
            group = [[class alloc] init];
            self.allTaskGroupInfo[aggregationKey] = group;
        }
    }
    ZZDownloadTaskGroupState originstate = group.state;
    //    ZZDownloadTaskInfo *oldtaskInfo = group.taskInfoDict[entity.entityKey];
    group.taskInfoDict[entity.entityKey] = taskInfo;
    
    if (taskInfo.state == ZZDownloadStateRemoved) {
        [group.taskInfoDict removeObjectForKey:entity.entityKey];
    }
    
    group.title = entity.aggregationTitle;
    group.coverUrl = [entity getCoverPath];
    group.key = [entity aggregationKey];
    group.realKey = [entity realKey];
    group.state = ZZDownloadTaskGroupStateWaiting;
    group.totalCount = group.taskInfoDict.allKeys.count;
    
    __block int32_t runningcount = 0;
    __block int32_t downloadedcount = 0;
    __block int32_t waitingCount = 0;
    
    [group.taskInfoDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, ZZDownloadTaskInfo *info, BOOL *stop){
        if (info.state == ZZDownloadStateDownloaded) {
            downloadedcount += 1;
        } else if (info.state == ZZDownloadStateDownloading) {
            runningcount += 1;
        } else if (taskInfo.state == ZZDownloadStateParsing || taskInfo.state == ZZDownloadStateDownloadingCover || taskInfo.state == ZZDownloadStateDownloadingDanmaku || taskInfo.state == ZZDownloadStateWaiting || taskInfo.state == ZZDownloadStateFail) {
            waitingCount += 1;
        }
    }];
    
    group.runningCount = runningcount;
    group.downloadedCount = downloadedcount;
    group.watingCount = waitingCount;
    
    if (group.runningCount > 0) {
        group.state = ZZDownloadTaskGroupStateDownloading;
    } else {
        group.state = ZZDownloadTaskGroupStatePaused;
        if (group.watingCount > 0) {
            group.state = ZZDownloadTaskGroupStateWaiting;
        }
    }
    if (group.downloadedCount == group.totalCount) {
        group.state = ZZDownloadTaskGroupStateDownloaded;
    }
    if (group.taskInfoDict.allKeys.count == 0 && group.key) {
        group.willRemove = YES;
        [self.allTaskGroupInfo removeObjectForKey:group.key];
    }
    
    gettimeofday(&container, NULL);
    uint64_t now = container.tv_sec * 1000 + container.tv_usec;
    if (self.allTaskNotificationTimeDict[group.key]) {
        self.allTaskNotificationTimeDict[group.key] = [NSNumber numberWithLong:0];
    }
    uint64_t old = [self.allTaskNotificationTimeDict[group.key] longValue];
    if (now - old > 1000 || group.state != originstate) {
        self.allTaskNotificationTimeDict[group.key] = [NSNumber numberWithLong:now];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZZDownloadTaskGroupNotifyUiNotification object:group];
    }
}
@end
