//
//  ZZDownloadNotifyManager.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadNotifyManager.h"
#import "EXTScope.h"
#import "ZZDownloadTask+Helper.h"
#import "ZZDownloadTaskInfo.h"
#import "SVProgressHUD.h"
#import <sys/time.h>
#import "ZZDownloader.h"

#define ZZDownloadNotifyQueueName @"ZZDownloadNotifyThread"

void * const ZZDownloadStateChangedContext = (void*)&ZZDownloadStateChangedContext;
NSString * const ZZDownloadTaskNotifyUiNotification = @"ZZDownloadTaskNotifyUiNotification";
NSString * const ZZDownloadTaskDiskSpaceWarningNotification = @"ZZDownloadTaskDiskSpaceWarningNotification";
NSString * const ZZDownloadTaskDiskSpaceErrorNotification = @"ZZDownloadTaskDiskSpaceErrorNotification";
NSString * const ZZDownloadTaskNetWorkChangedInterruptNotification = @"ZZDownloadTaskNetWorkChangedInterruptNotification";
NSString * const ZZDownloadTaskNetWorkChangedResumeNotification = @"ZZDownloadTaskNetWorkChangedResumeNotification";
NSString * const ZZDownloadTaskStartTaskUnderCelluar = @"ZZDownloadTaskStartTaskUnderCelluar";


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
        [[NSThread currentThread] setName:ZZDownloadNotifyQueueName];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

- (void)addOp:(ZZDownloadMessage *)message
{
    [self performSelector:@selector(doOp:) onThread:self.notifyThread withObject:message waitUntilDone:NO modes:[self.runLoopModes allObjects]];
}

- (void)doOp:(ZZDownloadMessage *)message
{
    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
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
    } else if (message.command == ZZDownloadMessageCommandNotifyStartTaskUnderCelluar) {
        [self notifyWithNotification:ZZDownloadTaskStartTaskUnderCelluar title:@"网络设置异常" message:@"如需在2G/3G环境下下载\n请在设置中勾选> <"];
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
    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    if (!key) {
        return;
    }
    [self notifyUi:key withCompletationBlock:nil];
    [self.allTaskInfoDict removeObjectForKey:key];
    
}

- (void)notifyUi:(NSString *)key withCompletationBlock:(void (^)(id))block
{
    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    ZZDownloadTaskInfo *task = self.allTaskInfoDict[key];
    if (task) {
        gettimeofday(&container, NULL);
        uint64_t now = container.tv_sec * 1000 + container.tv_usec;
        if (self.allTaskNotificationTimeDict[key]) {
            self.allTaskNotificationTimeDict[key] = [NSNumber numberWithLong:0];
        }
        uint64_t old = [self.allTaskNotificationTimeDict[key] longValue];
        
        BOOL focusUpdate = task.state != task.lastestState;
        if (now - old > 1000 || focusUpdate) {
            self.allTaskNotificationTimeDict[key] = [NSNumber numberWithLong:now];
            
            __block ZZDownloadTaskInfo *taskInfoblock = task;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:ZZDownloadTaskNotifyUiNotification object:taskInfoblock];
            });
        }
    }
    if (block) {
        block(self.allTaskInfoDict[key]);
    }
}

- (void)updateInfoWithTask:(ZZDownloadTask *)task
{
    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    if (!task || !task.key) {
        return;
    }
    
    BOOL newTask = NO;
    ZZDownloadTaskInfo *tmpTask = self.allTaskInfoDict[task.key];
    if (!tmpTask) {
        tmpTask = [[ZZDownloadTaskInfo alloc] init];
        tmpTask.key = task.key;
        tmpTask.entityType = task.entityType;
        self.allTaskInfoDict[task.key] = tmpTask;
        newTask = YES;
    }
    tmpTask.lastestState = tmpTask.state;
    tmpTask.state = task.state;
    tmpTask.command = task.command;
    [tmpTask updateSelfByArgv:task.argv];
    tmpTask.lastestError = task.lastestError;
    tmpTask.sectionsDownloadedList = task.sectionsDownloadedList;
    tmpTask.sectionsLengthList = task.sectionsLengthList;
    tmpTask.sectionsContentTime = task.sectionsContentTime;
    if (newTask) {
        [self notifyUi:tmpTask.key withCompletationBlock:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == ZZDownloadStateChangedContext) {
        if ([change[NSKeyValueChangeNewKey] unsignedIntegerValue] != [change[NSKeyValueChangeOldKey] unsignedIntegerValue]) {
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
    ZZDownloadQueueAssert(ZZDownloadNotifyQueueName);
    
    [self.allTaskInfoDict removeAllObjects];
}

@end
