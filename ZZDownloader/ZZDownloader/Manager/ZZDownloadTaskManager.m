//
//  ZZDownloadTaskManager.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadTaskManager.h"
#import "ZZDownloadOpOperation.h"
#import "ZZDownloadOpQueue.h"
#import <objc/runtime.h>

@interface ZZDownloadTaskManager () <ZZDownloadOpOperationDataSource, ZZDownloadOpOperationDelegate>

//@property (nonatomic, strong) NSMutableArray *opQueue;
@property (nonatomic, strong) NSMutableArray *allTask;

@property (nonatomic, strong) NSRecursiveLock *lock;

@end

@implementation ZZDownloadTaskManager

+ (id)shared
{
    static ZZDownloadTaskManager *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadTaskManager alloc] init];
//        queue.opQueue = [NSMutableArray array];
        queue.allTask = [NSMutableArray array];
        queue.lock = [[NSRecursiveLock alloc] init];
    });
    return queue;
}

- (void)addOp:(ZZDownloadOperation *)operation
{
    @synchronized(self) {
        [self updateAllInfoTaskByTask:operation];
        
        ZZDownloadOpOperation *opOperation = [[ZZDownloadOpOperation alloc] initWithOperation:operation];
        opOperation.delegate = self;
        opOperation.dataSource = self;
        [[ZZDownloadOpQueue shared] addOperation:opOperation];
    }
}

#pragma mark - DownloadOperation DataSource and Delegate
- (ZZDownloadTask *)getDownloadTaskByClass:(Class<MTLJSONSerializing>)taskClass withId:(NSString *)tId withKey:(NSString *)key
{
    for (int i = 0; i < self.allTask.count; i++) {
        ZZDownloadTask *task = self.allTask[i];
        BOOL classEqual = [NSStringFromClass(taskClass) isEqualToString:NSStringFromClass(task.class)];
        NSString *keyId = nil;
        NSString *selectorName = key;
        SEL sel = NSSelectorFromString(selectorName);
        if ([task respondsToSelector:sel]) {
            keyId = [task performSelector:sel];
        }
        BOOL idEqual = [tId isEqualToString:keyId];
        if (classEqual && idEqual) {
            return task;
            break;
        }
    }
    return nil;
}

- (void)startTask:(ZZDownloadTask *)task
{
    if (!task) {
        return;
    }
//    switch (task.state) {
//        case <#constant#>:
//            <#statements#>
//            break;
//            
//        default:
//            break;
//    }
}

- (void)stopTask:(ZZDownloadTask *)task
{

}

- (void)resumeTask:(ZZDownloadTask *)task
{

}

- (void)removeTask:(ZZDownloadTask *)task
{

}

- (void)checkTask:(ZZDownloadTask *)task
{

}

- (void)build
{

}

#pragma mark - internal method
- (void)updateAllInfoTaskByTask:(ZZDownloadOperation *)operation
{
    ZZDownloadTask *existedTask = nil;
    for (int i = 0; i < self.allTask.count; i++) {
        ZZDownloadTask *task = self.allTask[i];
        BOOL classEqual = [NSStringFromClass(operation.taskClass) isEqualToString:NSStringFromClass(task.class)];
        NSString *keyId = nil;
        NSString *selectorName = operation.key;
        SEL sel = NSSelectorFromString(selectorName);
        if ([task respondsToSelector:sel]) {
            keyId = [task performSelector:sel];
        }
        BOOL idEqual = [operation.tId isEqualToString:keyId];
        if (classEqual && idEqual) {
            existedTask = task;
            break;
        }
    }
   
    if (existedTask) {
        switch (operation.command) {
            case ZZDownloadCommandStart:
                switch (existedTask.state) {
                    case ZZDownloadStatePaused:
                        existedTask.state = ZZDownloadStateWaiting;
                        break;
                    case ZZDownloadStateShouldPause:
                        existedTask.state = ZZDownloadStateWaiting;
                        break;
                    // 是否处理invalid?
                    default:
                        break;
                }
                break;
            case ZZDownloadCommandStop:
                switch (existedTask.state) {
                    case ZZDownloadStateDownloaded:
                        NSLog(@"downloaded");
                        break;
                    case ZZDownloadStateDownloading:
                        existedTask.state = ZZDownloadStateShouldPause;
                        break;
                    case ZZDownloadStateWaiting:
                        existedTask.state = ZZDownloadStatePaused;
                        break;
                    default:
                        break;
                }
                break;
            case ZZDownloadCommandRemove:
                switch (existedTask.state) {
                    case ZZDownloadStateWaiting:
                        [self deleteTaskAndFile:existedTask];
                        break;
                    case ZZDownloadStatePaused:
                        [self deleteTaskAndFile:existedTask];
                        break;
                    case ZZDownloadStateShouldPause:
                        existedTask.state = ZZDownloadStateShouldRemove;
                        break;
                    case ZZDownloadStateDownloaded:
                        [self deleteTaskAndFile:existedTask];
                        break;
                    case ZZDownloadStateDownloading:
                        existedTask.state = ZZDownloadStateShouldRemove;
                        break;
                    default:
                        break;
                }
                break;
            case ZZDownloadCommandResume:
                // MARK
                switch (existedTask.state) {
                    case ZZDownloadStatePaused:
                        existedTask.state = ZZDownloadStateWaiting;
                        break;
                    case ZZDownloadStateShouldPause:
                        existedTask.state = ZZDownloadStateWaiting;
                        break;
                    default:
                        break;
                }
                break;
            case ZZDownloadCommandCheck:
                //do nothing
                break;
            case ZZDownloadCommandBuild:
                [self buildAllTaskInfo];
                break;
            default:
                break;
        }
    } else {
        Class task = operation.taskClass;
        ZZDownloadTask *t = [[task alloc] init];
        t.state = ZZDownloadStateWaiting;
        [self addTaskToInfo:t];
    }
}

- (void)buildAllTaskInfo
{

}

- (void)addTaskToInfo:(ZZDownloadTask *)task
{
    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
        [self.allTask addObject:task];
    }];
}

- (void)deleteTaskAndFile:(ZZDownloadTask *)task
{
    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
        [self.allTask removeObject:task];
        // delete file
    }];
}

@end
