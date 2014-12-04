//
//  ZZDownloadNotifyManager.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadNotifyQueue.h"
#import "ZZDownloadTaskManager.h"
#import "EXTScope.h"
#import "ZZDownloadTask+Helper.h"
#import "ZZDownloadTaskInfo.h"

void * const ZZDownloadStateChangedContext = (void*)&ZZDownloadStateChangedContext;
NSString * const ZZDownloadTaskNotifyUiNotification = @"ZZDownloadTaskNotifyUiNotification";

@interface ZZDownloadNotifyManager ()

@property (nonatomic, strong) NSMutableDictionary *allTaskInfoDict;

@end

@implementation ZZDownloadNotifyManager
+ (id)shared
{
    static ZZDownloadNotifyManager *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadNotifyManager alloc] init];
        queue.allTaskInfoDict = [NSMutableDictionary dictionary];
        ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
        message.command = ZZDownloadMessageCommandNeedBuild;
        [queue addOp:message];
    });
    return queue;
}

- (void)addOp:(ZZDownloadMessage *)message
{
    [[ZZDownloadNotifyQueue shared] addOperationWithBlock:^{
        [self doOp:message];
    }];
}

- (void)doOp:(ZZDownloadMessage *)message
{
    if (message.command == ZZDownloadMessageCommandNeedBuild) {
        [self buildAllTaskInfo];
        return;
    }
    if (message.command == ZZDownloadMessageCommandNeedUpdateInfo) {
        [self updateInfoWithTask:message.task];
    } else if (message.command == ZZDownloadMessageCommandNeedNotifyUI) {
        [self notifyUi:message.key withCompletationBlock:nil];
    } else if (message.command == ZZDownloadMessageCommandNeedNotifyUIByCheck) {
        [self notifyUi:message.key withCompletationBlock:message.block];
    } else if (message.command == ZZDownloadMessageCommandRemoveTaskInfo) {
        [self removeTaskInfo:message.key];
    }
}

- (void)removeTaskInfo:(NSString *)key
{
    if (!key) {
        return;
    }
    [self notifyUi:key withCompletationBlock:nil];
    [self.allTaskInfoDict removeObjectForKey:key];
}

- (void)notifyUi:(NSString *)key withCompletationBlock:(void (^)(id))block
{
    ZZDownloadTaskInfo *task = self.allTaskInfoDict[key];
    if (task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:ZZDownloadTaskNotifyUiNotification object:task];
        });
    }
    if (block) {
        block(self.allTaskInfoDict[key]);
    }
}

- (void)updateInfoWithTask:(ZZDownloadTask *)task
{
    if (!task || !task.key) {
        return;
    }
    ZZDownloadTaskInfo *tmpTask = self.allTaskInfoDict[task.key];
    if (!tmpTask) {
        tmpTask = [[ZZDownloadTaskInfo alloc] init];
        tmpTask.key = task.key;
        tmpTask.entityType = task.entityType;
        self.allTaskInfoDict[task.key] = tmpTask;
        [self notifyUi:task.key withCompletationBlock:nil];
    }
    tmpTask.state = task.state;
    tmpTask.command = task.command;
    tmpTask.argv = task.argv;
    tmpTask.lastestError = task.lastestError;
    tmpTask.sectionsDownloadedList = task.sectionsDownloadedList;
    tmpTask.sectionsLengthList = task.sectionsLengthList;
    tmpTask.sectionsContentTime = task.sectionsContentTime;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == ZZDownloadStateChangedContext) {
        if ([change[NSKeyValueChangeNewKey] unsignedIntegerValue] != [change[NSKeyValueChangeOldKey] unsignedIntegerValue]) {
//            NSLog(@"key=%@ old = %@ new = %@", [object key], change[@"old"], change[@"new"]);
            ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
            
            message.command = ZZDownloadMessageCommandNeedUpdateInfo;
            message.key = [object key];
            message.task = object;
            [self addOp:message];
            
            ZZDownloadMessage *notifyMessage = [[ZZDownloadMessage alloc] init];
            notifyMessage.command = ZZDownloadMessageCommandNeedNotifyUI;
            notifyMessage.key = [object key];
            [self addOp:notifyMessage];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)buildAllTaskInfo
{
    [self.allTaskInfoDict removeAllObjects];
}

@end
