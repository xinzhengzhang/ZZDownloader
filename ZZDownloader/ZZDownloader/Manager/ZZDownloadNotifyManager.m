//
//  ZZDownloadNotifyManager.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadNotifyQueue.h"
#import "EXTScope.h"
#import "ZZDownloadTask+Helper.h"
#import "ZZDownloadTaskInfo.h"
#import "SVProgressHUD.h"
#import <sys/time.h>
#import "ZZDownloader.h"

void * const ZZDownloadStateChangedContext = (void*)&ZZDownloadStateChangedContext;
NSString * const ZZDownloadTaskNotifyUiNotification = @"ZZDownloadTaskNotifyUiNotification";
NSString * const ZZDownloadTaskDiskSpaceWarningNotification = @"ZZDownloadTaskDiskSpaceWarningNotification";
NSString * const ZZDownloadTaskDiskSpaceErrorNotification = @"ZZDownloadTaskDiskSpaceErrorNotification";
NSString * const ZZDownloadTaskNetWorkChangedInterruptNotification = @"ZZDownloadTaskNetWorkChangedInterruptNotification";
NSString * const ZZDownloadTaskNetWorkChangedResumeNotification = @"ZZDownloadTaskNetWorkChangedResumeNotification";

@interface ZZDownloadNotifyManager () {
    struct timeval container;
}

@property (nonatomic, strong) NSMutableDictionary *allTaskInfoDict;
@property (nonatomic, strong) NSMutableDictionary *allTaskNotificationTimeDict;
@property (nonatomic) BOOL showAlert;
@property (nonatomic) NSThread *notifyThread;
@property (nonatomic) NSSet *runLoopModes;
@end

@implementation ZZDownloadNotifyManager
+ (id)shared
{
    static ZZDownloadNotifyManager *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadNotifyManager alloc] init];
        queue.allTaskInfoDict = [NSMutableDictionary dictionary];
        queue.allTaskNotificationTimeDict = [NSMutableDictionary dictionary];
        ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
        queue.notifyThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [queue.notifyThread start];
        queue.showAlert = NO;
        message.command = ZZDownloadMessageCommandNeedBuild;
        queue.runLoopModes = [NSSet setWithObject:NSRunLoopCommonModes];
        [queue addOp:message];
    });
    return queue;
}

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"ZZDownloadNotifyThread"];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

- (void)addOp:(ZZDownloadMessage *)message
{
    [self performSelector:@selector(doOp:) onThread:self.notifyThread withObject:message waitUntilDone:NO modes:[self.runLoopModes allObjects]];
    //    __block ZZDownloadMessage *x = message;
    //        [[ZZDownloadNotifyQueue shared] addOperationWithBlock:^{
    //            [self doOp:x];
    //        }];
}

- (void)doOp:(ZZDownloadMessage *)message
{
    //    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    @autoreleasepool {
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
        } else if (message.command == ZZDownloadMessageCommandNotifyDiskWarning) {
            [self notifyWithNotification:ZZDownloadTaskDiskSpaceWarningNotification title:@"磁盘要爆炸了啊(-｡-;)" message:@"空间已经小于300M、注意及时清理哟"];
        } else if (message.command == ZZDownloadMessageCommandNotifyDiskBakuhatu) {
            [self notifyWithNotification:ZZDownloadTaskDiskSpaceErrorNotification title:@"磁盘要爆炸了啊(-｡-;)" message:@"空间小于100M、已经开启自动防御停止下载了哦、注意及时清理"];
        } else if (message.command == ZZDownloadMessageCommandNotifyNetWorkChangedInterrupt) {
            [self notifyWithNotification:ZZDownloadTaskNetWorkChangedInterruptNotification title:@"穿越注意穿越注意(-｡-;)" message:@"网络环境变化、自动防御开启、下载停止ˊ_>ˋ"];
        } else if (message.command == ZZDownloadMessageCommandNotifyNetworkChangedResume) {
            [self notifyWithNotification:ZZDownloadTaskNetWorkChangedResumeNotification title:@"穿越注意穿越注意(-｡-;)" message:@"恢复下载、恢复下载ˊ_>ˋ"];
        }
    }
}

- (void)notifyWithNotification:(NSString *)notificationName title:(NSString *)title message:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:nil];
        if (!self.showAlert) {
            self.showAlert = YES;
            if (notificationName == ZZDownloadTaskDiskSpaceErrorNotification) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"我知道了ˊ_>ˋ" otherButtonTitles:nil];
                [self performSelectorOnMainThread:@selector(show) withObject:alert waitUntilDone:NO];
            } else {
                if (notificationName == ZZDownloadTaskNetWorkChangedResumeNotification) {
                    [SVProgressHUD showSuccessWithStatus:message];
                } else {
                    [SVProgressHUD showErrorWithStatus:message];
                }
                self.showAlert = NO;
            }
        }
        
    });
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    self.showAlert = NO;
}

- (void)removeTaskInfo:(NSString *)key
{
    //    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    if (!key) {
        return;
    }
    [self notifyUi:key withCompletationBlock:nil];
    [self.allTaskInfoDict removeObjectForKey:key];
}

- (void)notifyUi:(NSString *)key withCompletationBlock:(void (^)(id))block
{
    //    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    __block ZZDownloadTaskInfo *task = self.allTaskInfoDict[key];
    if (task) {
        gettimeofday(&container, NULL);
        uint64_t now = container.tv_sec * 1000 + container.tv_usec;
        if (self.allTaskNotificationTimeDict[key]) {
            self.allTaskNotificationTimeDict[key] = [NSNumber numberWithLong:0];
        }
        uint64_t old = [self.allTaskNotificationTimeDict[key] longValue];
        self.allTaskNotificationTimeDict[key] = [NSNumber numberWithLong:now];
        if (now - old > 1000) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (task.argv) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:ZZDownloadTaskNotifyUiNotification object:task];
                }
            });
        }
    }
    if (block) {
        block(self.allTaskInfoDict[key]);
    }
}

- (void)updateInfoWithTask:(ZZDownloadTask *)task
{
    //    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    if (!task || !task.key) {
        return;
    }
    ZZDownloadTaskInfo *tmpTask = self.allTaskInfoDict[task.key];
    if (!tmpTask) {
        tmpTask = [[ZZDownloadTaskInfo alloc] init];
        tmpTask.key = task.key;
        tmpTask.entityType = task.entityType;
        self.allTaskInfoDict[task.key] = tmpTask;
        [self notifyUi:tmpTask.key withCompletationBlock:nil];
    }
    tmpTask.lastestState = tmpTask.state;
    tmpTask.state = task.state;
    tmpTask.command = task.command;
    if (!task.argv) {
        NSLog(@"~~~");
    }
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
            ZZDownloadTask *task = [object deepCopy];
            message.command = ZZDownloadMessageCommandNeedUpdateInfo;
            message.key = [task key];
            message.task = task;
            [self addOp:message];
            
            ZZDownloadMessage *notifyMessage = [[ZZDownloadMessage alloc] init];
            notifyMessage.command = ZZDownloadMessageCommandNeedNotifyUI;
            notifyMessage.key = [task key];
            [self addOp:notifyMessage];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)buildAllTaskInfo
{
    //    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    [self.allTaskInfoDict removeAllObjects];
}

@end
