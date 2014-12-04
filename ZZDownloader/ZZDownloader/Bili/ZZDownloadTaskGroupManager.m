//
//  BiliDownloadTaskGroupManager.m
//  ibiliplayer
//
//  Created by zhangxinzheng on 11/26/14.
//  Copyright (c) 2014 Zhang Rui. All rights reserved.
//

#import "ZZDownloadTaskGroupManager.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadTaskInfo.h"


#define BiliDownloadValidGroupTask @[@"BiliDownloadAvGroup"]

NSString * const ZZDownloadTaskGroupNotifyUiNotification = @"ZZDownloadTaskGroupNotifyUiNotification";

@interface ZZDownloadTaskGroupManager ()

@property (nonatomic) NSMutableDictionary *allTaskGroupInfo;
@property (nonatomic) dispatch_queue_t managerQueue;

@end

@implementation ZZDownloadTaskGroupManager

+ (id)shared
{
    static ZZDownloadTaskGroupManager *share;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[ZZDownloadTaskGroupManager alloc] init];
        share.allTaskGroupInfo = [NSMutableDictionary dictionary];
        share.managerQueue = dispatch_queue_create("com.zzdownloader.bilitaskgroupmanager.groupmanager.queue", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:share selector:@selector(notifyReceived:) name:ZZDownloadTaskNotifyUiNotification object:nil];
    });
    return share;
}

- (void)checkAllTaskWithId:(NSString *)aggregationKey withCompletationBlock:(void (^)(ZZDownloadTaskGroup *))block
{
    dispatch_async(self.managerQueue, ^{
        ZZDownloadTaskGroup *group = self.allTaskGroupInfo[aggregationKey];
        block(group);
    });
}

- (void)checkAllTaskGroupWithCompletationBlock:(void (^)(NSArray *))block
{
    dispatch_async(self.managerQueue, ^{
        block([self.allTaskGroupInfo allValues]);
    });
}

- (void)notifyReceived:(NSNotification *)aNotification
{
    ZZDownloadTaskInfo *taskInfo = aNotification.object;
    if (!taskInfo) {
        return;
    }
    dispatch_async(self.managerQueue, ^{
        [self dealTaskInfo:taskInfo];
    });
}

- (void)dealTaskInfo:(ZZDownloadTaskInfo *)taskInfo
{
    ZZDownloadBaseEntity *entity = [taskInfo recoverEntity];
    NSString *aggregationKey = [entity aggregationKey];
    ZZDownloadTaskGroup *group = self.allTaskGroupInfo[aggregationKey];
   
    if (!group) {
        NSString *type = [entity aggregationType];
        if ([BiliDownloadValidGroupTask containsObject:type]) {
            Class class = NSClassFromString(type);
            group = [[class alloc] init];
            self.allTaskGroupInfo[aggregationKey] = group;
        }
    }
    if (!group.taskInfoDict[entity.entityKey]) {
        [entity downloadCoverWithDownloadStartBlock:nil];
    }
    group.taskInfoDict[entity.entityKey] = taskInfo;
 
    if (taskInfo.state == ZZDownloadStateRemoved) {
        [group.taskInfoDict removeObjectForKey:entity.entityKey];
    }
    
    group.title = entity.title;
    group.coverUrl = [entity getCoverPath];
    group.key = [entity aggregationKey];
    group.realKey = [entity realKey];
    group.state = ZZDownloadTaskGroupStateWaiting;
    
    __block BOOL downloaded = YES;
    __block BOOL downloading = NO;
    __block BOOL waiting = NO;
    [group.taskInfoDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, ZZDownloadTaskInfo *ti, BOOL *stop) {
        if (ti.state != ZZDownloadStateDownloaded) {
            downloaded = NO;
        }
        if (ti.state == ZZDownloadStateWaiting) {
            waiting = YES;
        }
        if (ti.state == ZZDownloadStateDownloading) {
            downloading = YES;
            downloaded = NO;
        }
    }];
    if (downloading) {
        group.state = ZZDownloadTaskGroupStateDownloading;
    } else if (downloaded) {
        group.state = ZZDownloadTaskGroupStateDownloaded;
    } else if (waiting){
        group.state = ZZDownloadTaskGroupStateWaiting;
    } else {
        group.state = ZZDownloadTaskGroupStatePaused;
    }
    if (group.taskInfoDict.allKeys.count == 0) {
        [self.allTaskGroupInfo removeObjectForKey:group.key];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:ZZDownloadTaskGroupNotifyUiNotification object:group];
    });
}
@end
