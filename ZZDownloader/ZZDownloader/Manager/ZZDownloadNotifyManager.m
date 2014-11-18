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

void * const ZZDownloadStateChangedContext = (void*)&ZZDownloadStateChangedContext;

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
//    ZZDownloadTask *existedTask = self.allTaskInfoDict[message.key];
//    if (!existedTask) {
//        existedTask = [[ZZDownloadTask alloc] init];
//        existedTask.key = message.key;
//        existedTask.entityType
//    }
    if (message.command == ZZDownloadMessageCommandNeedUpdateInfo) {
        [self updateInfoWithTask:message.task];
    } else if (message.command == ZZDownloadMessageCommandNeedNotifyUI) {
        // send notification
    }
}

- (void)updateInfoWithTask:(ZZDownloadTask *)task
{
    if (!task || !task.key) {
        return;
    }
    ZZDownloadTask *tmpTask = self.allTaskInfoDict[task.key];
    if (!tmpTask) {
        tmpTask = [[ZZDownloadTask alloc] init];
        tmpTask.entityType = task.entityType;
        tmpTask.key = task.key;
        self.allTaskInfoDict[task.key] = tmpTask;
    }
    tmpTask.state = task.state;
    tmpTask.command = task.command;
    // 性能
    tmpTask.argv = [task.argv copy];
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
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)buildAllTaskInfo
{
    [self.allTaskInfoDict removeAllObjects];
    NSArray *filePathList = [ZZDownloadTaskManager getBiliTaskFilePathList];
    NSError *error;
    for (NSString *filePath in filePathList) {
        NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
        if (error) {
            NSLog(@"%@", error);
            continue;
        }
        NSDictionary *rdict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (error) {
            NSLog(@"%@", error);
            continue;
        }
        ZZDownloadTask *rtask = [MTLJSONAdapter modelOfClass:[ZZDownloadTask class] fromJSONDictionary:rdict error:&error];
        if (error) {
            NSLog(@"%@", error);
            continue;
        }
        if (rtask.key) {
            self.allTaskInfoDict[rtask.key] = rtask;
        }
    }
}

@end
