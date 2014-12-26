//
//  ZZDownloadTaskManager.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadTaskManager.h"
#import "ZZDownloadOpQueue.h"
#import <CommonCrypto/CommonDigest.h>
#import "ZZDownloadBaseEntity.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadMessage.h"
#import "ZZDownloadRequestOperation.h"
#import "ZZDownloadUrlConnectionQueue.h"
#import "ZZDownloadTask+Helper.h"
#import "ZZDownloadTaskGroupManager.h"
#import "EXTScope.h"
#import "libavformat/version.h"
#import "Reachability.h"
#include <sys/param.h>
#include <sys/mount.h>

#define ZZDownloadTaskManagerTaskDir @".Downloads/zzdownloadtaskmanagertask"
#define ZZDownloadTaskManagerTaskFileDir @".Downloads/zzdownloadtaskmanagertaskfile"

@interface ZZDownloadTaskManager ()

// 所有操作在op queue
@property (nonatomic, strong) NSMutableDictionary *allTaskDict;
// 所有操作在 manager quque
@property (nonatomic, strong) NSMutableArray *allDownloadRequests;

@property (nonatomic, strong) ZZDownloadRequestOperation *runningOperation;
@property (nonatomic) dispatch_queue_t managerQueue;
@property (nonatomic) dispatch_queue_t luaQueue;
@property (nonatomic) BOOL couldDownload;
@end


@implementation ZZDownloadTaskManager

+ (id)shared
{
    static ZZDownloadTaskManager *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadTaskManager alloc] init];
        queue.allTaskDict = [NSMutableDictionary dictionary];
        queue.allDownloadRequests = [NSMutableArray array];
        queue.managerQueue = dispatch_queue_create("com.zzdownloader.taskmanager.operation.quque", DISPATCH_QUEUE_SERIAL);
        queue.luaQueue = dispatch_queue_create("com.zzdownloader.taskmanager.lua.queue", DISPATCH_QUEUE_SERIAL);
        ZZDownloadOperation *op = [[ZZDownloadOperation alloc] init];
        op.command = ZZDownloadCommandBuild;
        [queue doOp:op entity:nil block:nil];
        queue.couldDownload = YES;
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [NSTimer scheduledTimerWithTimeInterval:1 target:queue selector:@selector(notifyDownloadUpdateMessage) userInfo:nil repeats:YES];
//            [NSTimer scheduledTimerWithTimeInterval:30 target:queue selector:@selector(watchDog) userInfo:nil repeats:YES];
//        });
    });
    return queue;
}

- (void)addOp:(ZZDownloadOperation *)operation withEntity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block

{
    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
        [self doOp:operation entity:entity block:block];
    }];
}

- (BOOL)isDownloading
{
    return (self.runningOperation != nil && ![self.runningOperation isPaused]);
}

#pragma mark - internal method
- (void)addTaskByEntity:(ZZDownloadBaseEntity *)entity updateTask:(BOOL)yesOrNo
{
    NSString *key = [entity entityKey];
    if (!key) {
        return;
    }
    if (!self.allTaskDict[key]) {
        ZZDownloadTask *task = [ZZDownloadTask buildTaskFromDisk:[MTLJSONAdapter JSONDictionaryFromModel:entity]];
        task.key = key;
        task.entityType = NSStringFromClass([entity class]);
        [task addObserver:[ZZDownloadNotifyManager shared] forKeyPath:@"state" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:ZZDownloadStateChangedContext];
        [self notifyQueueUpdateMessage:task];
        if ([self writeTaskToDisk:task]) {
            self.allTaskDict[key] = task;
        }
    } else if (yesOrNo){
        ZZDownloadTask *task = self.allTaskDict[key];
        task.argv = [MTLJSONAdapter JSONDictionaryFromModel:entity];
    }
    
}

- (BOOL)writeTaskToDisk:(ZZDownloadTask *)task
{
    NSError *error;
    NSDictionary *dict = [MTLJSONAdapter JSONDictionaryFromModel:task];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeTransferError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"task:%@ data transfer to dict fail", task.key], @"originError": error}];
        return NO;
    }
    NSString *targtetPath = [[ZZDownloadTaskManager taskFolder] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bilitask", task.key]];
    [jsonData writeToFile:targtetPath options:NSDataWritingAtomic error:&error];
    if (error) {
        task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"task:%@ write to file fail", task.key], @"originError": error}];
        return NO;
    }
    return YES;
}

- (void)doOp:(ZZDownloadOperation *)operation entity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block
{
    if (operation.command == ZZDownloadCommandBuild) {
        dispatch_sync(self.managerQueue, ^{
            [self buildAllTaskInfo];
        });
        return;
    }
    if (operation.command == ZZDownloadCommandCheck) {
        ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
        message.command = ZZDownloadMessageCommandNeedNotifyUIByCheck;
        message.key = entity.entityKey;
        message.block = block;
        [[ZZDownloadNotifyManager shared] addOp:message];
        return;
    }
    if (operation.command == ZZDownloadCommandCheckGroup) {
        [[ZZDownloadTaskGroupManager shared] checkAllTaskWithId:[entity aggregationKey] withCompletationBlock:block];
        return;
    }
    if (operation.command == ZZDownloadCommandResumeAll) {
        [self resumeAllTask];
        return;
    }
    if (operation.command == ZZDownloadCommandPauseAll) {
        [self pauseAllTask];
        return;
    }
    if (operation.command == ZZDownloadCommandCheckAllGroup) {
        [[ZZDownloadTaskGroupManager shared] checkAllTaskGroupWithCompletationBlock:block];;
        return;
    }
    dispatch_sync(self.managerQueue, ^{
        [self addTaskByEntity:entity updateTask:operation.command == ZZDownloadCommandStart];
    });
    
    ZZDownloadTask *existedTask = self.allTaskDict[operation.key];
    if (existedTask) {
        @weakify(self);
        switch (operation.command) {
            case ZZDownloadCommandStart:
            {
                if ([self settingCouldDownload]) {
                    [existedTask startWithStartSuccessBlock:^{
                        @strongify(self);
                        [self startTask:existedTask fifo:YES];
                    }];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[[UIAlertView alloc] initWithTitle:@"网络设置异常" message:@"如需在蜂窝下开启下载请在设置中勾选> <" delegate:nil cancelButtonTitle:@"知道啦" otherButtonTitles:nil] show];
                    });
                }
                break;
            }
            case ZZDownloadCommandStop:
            {
                [existedTask pauseWithPauseSuccessBlock:^{
                    @strongify(self);
                    [self pauseTask:existedTask ukeru:NO];
                } ukeru:NO];
                break;
            }
            case ZZDownloadCommandInterruptStop:
            {
                [existedTask pauseWithPauseSuccessBlock:^{
                    @strongify(self);
                    [self pauseTask:existedTask ukeru:YES];
                } ukeru:YES];
                break;
            }
            case ZZDownloadCommandRemove:
            {
                [existedTask removeWithRemoveSuccessBlock:^{
                    @strongify(self);
                    [self removeTask:existedTask];
                }];
                break;
            }
            default:
                break;
        }
        [self notifyQueueUpdateMessage:existedTask];
        if (operation.command != ZZDownloadCommandRemove) {
            [self writeTaskToDisk:existedTask];
        }
    } else {
        NSLog(@"warning! unknow task");
    }
}

- (BOOL)settingCouldDownload
{
    if (self.enableDownloadUnderWWAN) {
        return YES;
    }
    Reachability* curReach = [Reachability reachabilityWithHostName:@"www.baidu.com"];
    NetworkStatus status = [curReach currentReachabilityStatus];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    if (status == kNotReachable) {
        return NO;
    }
    else if (status == kReachableViaWiFi) {
        return YES;
    }
    else if (status == kReachableViaWWAN) {
        return NO;
    }
    return NO;
}

- (void)assignDownloadSectionTask:(ZZDownloadBaseEntity *)entity fifo:(BOOL)yesOrNo
{
    if (!entity || !self.allTaskDict[entity.entityKey]) {
        return;
    }

    ZZDownloadTask *existedTask = self.allTaskDict[entity.entityKey];
    existedTask.argv = [MTLJSONAdapter JSONDictionaryFromModel:entity];
//        existedTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey:@"网络环境设置无法下载"}];
//        existedTask.command = ZZDownloadAssignedCommandNone;
//        [self notifyQueueUpdateMessage:existedTask];
//        return;
//    }
    dispatch_async(self.luaQueue, ^{
    
        ZZDownloadState ts = existedTask.state;
        existedTask.state = ZZDownloadStateParsing;
        
        NSString *needTypeTag = [entity getTypeTag:YES];
        int32_t sectionCount = [entity getSectionCount];

        BOOL x1 = sectionCount != 0 && sectionCount != existedTask.sectionsLengthList.count;
        BOOL x2 = sectionCount != 0 && sectionCount != existedTask.sectionsDownloadedList.count;
        BOOL x3 = !needTypeTag || ((existedTask.argv[@"typeTag"] != NSNull.null) && [existedTask.argv[@"typeTag"] isEqualToString:needTypeTag]);
       
        dispatch_sync(self.managerQueue, ^{
            existedTask.argv = [MTLJSONAdapter JSONDictionaryFromModel:entity];
        });
        
        // 判断任务是否过期
        if (x1 || x2 || !x3) {
            dispatch_sync(self.managerQueue, ^{
                [self overdueTask:existedTask];
                for (int i = 0; i < sectionCount; i++) {
                    [existedTask.sectionsDownloadedList addObject:[NSNumber numberWithLongLong:0]];
                    [existedTask.sectionsLengthList addObject:[NSNumber numberWithLongLong:0]];
                    [existedTask.sectionsContentTime addObject:[NSNumber numberWithUnsignedInteger:0]];
                }
            });
        }
       
        [entity downloadDanmakuWithDownloadStartBlock:^{
            existedTask.state = ZZDownloadStateDownloadingDanmaku;
        }];
        [entity downloadCoverWithDownloadStartBlock:^{
            existedTask.state = ZZDownloadStateDownloadingCover;
        }];
        existedTask.state = ts;
        
        NSString *destinationPath = [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
        if (sectionCount == 0) {
            existedTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"task parse fail:%@command:%d state:%d", existedTask.key, (int32_t)existedTask.command, (int32_t)existedTask.state]}];
            existedTask.command = ZZDownloadAssignedCommandNone;
            [self dealFailTask:existedTask];
        }
        NSArray *existedFile = [ZZDownloadTaskManager getBiliTaskFileNameList:destinationPath suffix:@"section"];
        for (int i = 0; i < sectionCount; i++) {
            if ([existedFile containsObject:[NSString stringWithFormat:@"%d.section", i]]) {
                if (i == sectionCount-1) {
                    existedTask.state = ZZDownloadStateDownloaded;
                    existedTask.lastestError = nil;
                    [self notifyQueueUpdateMessage:existedTask];
                    existedTask.command = ZZDownloadAssignedCommandNone;
                    [self writeTaskToDisk:existedTask];
                    dispatch_async(self.managerQueue, ^{
                        [self executeDownloadQueue];
                    });
                }
                continue;
            } else {
                existedTask.state = ZZDownloadStateWaiting;
                NSString *targetPath = [destinationPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.section",i]];
                NSUInteger totalLength = [entity getSectionTotalLengthWithCount:i];
                existedTask.sectionsContentTime[i] = [NSNumber numberWithUnsignedInteger:totalLength];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[entity getSectionUrlWithCount:i]]];
                [request addValue:[NSString stringWithUTF8String:LIBAVFORMAT_IDENT] forHTTPHeaderField:@"User-Agent"];
                BOOL focusContentRange = ![existedTask.argv[@"from"] isEqual:NSNull.null] && [existedTask.argv[@"from"] isEqualToString:@"pptv"];
                ZZDownloadRequestOperation *rq = [[ZZDownloadRequestOperation alloc] initWithRequest:request targetPath:targetPath shouldResume:YES forcusContentRange:focusContentRange];
                rq.key = entity.entityKey;
                
#if BILITEST==1
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[UIAlertView alloc] initWithTitle:existedTask.key message:request.URL.absoluteString delegate:nil cancelButtonTitle:@"quxiao" otherButtonTitles: nil] show];

                });
#endif
                [rq setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile){
                    if (existedTask.state != ZZDownloadStateDownloading && existedTask.command != ZZDownloadAssignedCommandRemove) {
                        if (bytesRead > 0) {
                            existedTask.state = ZZDownloadStateDownloading;
                            existedTask.command = ZZDownloadAssignedCommandNone;
                        }
                    }
                    
                    long long tmpLength = [existedTask.sectionsLengthList[i] longLongValue];
                    for (int j = i; j < existedTask.sectionsLengthList.count; j++) {
                        existedTask.sectionsLengthList[j] = [NSNumber numberWithLongLong:tmpLength];
                    }
                    existedTask.sectionsLengthList[i] = [NSNumber numberWithLongLong:totalBytesExpectedToReadForFile];
                    existedTask.sectionsDownloadedList[i] = [NSNumber numberWithLongLong:totalBytesReadForFile];
    //                NSLog(@"i am %@-%d,my progress = %f", existedTask.key, i,totalBytesReadForFile*1.0 / totalBytesExpectedToReadForFile);
                }];
                
                [rq setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                    if (operation.response.statusCode >= 200 && operation.response.statusCode < 400 && [self videoFileValid:targetPath]) {
                        NSLog(@"i downloaded %@-%d", existedTask.key, i);
                        existedTask.command = ZZDownloadAssignedCommandStart;
                        existedTask.state = ZZDownloadStateWaiting;
                        existedTask.triedCount = 0;
                        [self startTask:existedTask fifo:NO];
                    } else if (operation.response.statusCode >= 400) {
                        [[NSFileManager defaultManager] removeItemAtPath:targetPath error:NULL];
                        existedTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeHttpError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"task:%@ errorCode:%d -http error happened", existedTask.key, (int32_t)operation.response.statusCode]}];
                        [self dealFailTask:existedTask];
                    }
                    [self notifyQueueUpdateMessage:existedTask];
                } failure:^(AFHTTPRequestOperation *operation, NSError *error){
                    NSLog(@"error key=%@ happened = %@",existedTask.key, error);
                    if (error) {
                        existedTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"task:%@ interrupted command:%d state:%d", existedTask.key, (int32_t)existedTask.command, (int32_t)existedTask.state], @"originError": error}];
                    } else {
                        existedTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"task:%@ interrupted command:%d state:%d", existedTask.key, (int32_t)existedTask.command, (int32_t)existedTask.state]}];
                    }
                    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
    //                    [(ZZDownloadRequestOperation *)operation deleteTempFileWithError:nil];
    //                    [self deleteTask:existedTask];
    //                    [self pauseAllTask];
                        existedTask.command = ZZDownloadAssignedCommandNone;
                        existedTask.state = ZZDownloadStateInvalid;
                        [self notifyQueueUpdateMessage:existedTask];
                        return;
                    }
                    
                    // 暂停一个正在下载的任务也会进这
                    NSLog(@"i was interppted %@", existedTask.key);
                    if (existedTask.command == ZZDownloadAssignedCommandRemove) {
    //                    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
    //                        [self deleteTask:existedTask];
    //                    }];
                        dispatch_async(self.managerQueue, ^{
                            [self deleteTask:existedTask];
                            [self executeDownloadQueue];
                        });
                    } else if ((existedTask.command == ZZDownloadAssignedCommandNone || existedTask.command == ZZDownloadAssignedCommandStart) && (existedTask.state == ZZDownloadStateDownloading || existedTask.state == ZZDownloadStateWaiting)) {
                        [self dealFailTask:existedTask];
                    } else if (existedTask.command == ZZDownloadAssignedCommandPause && (existedTask.state == ZZDownloadStateDownloading || existedTask.state == ZZDownloadStateWaiting)){
                        existedTask.state = ZZDownloadStateRealPaused;
                        dispatch_async(self.managerQueue, ^{
                            [self executeDownloadQueue];
                        });
                    } else if (existedTask.command == ZZDownloadAssignedCommandInterruptPaused) {
                        existedTask.state = ZZDownloadStateInterrputPaused;
                        dispatch_async(self.managerQueue, ^{
                            [self executeDownloadQueue];
                        });
                    } else {
                        dispatch_async(self.managerQueue, ^{
                            [self executeDownloadQueue];
                        });
                    }
                    existedTask.command = ZZDownloadAssignedCommandNone;
                    [self notifyQueueUpdateMessage:existedTask];
                }];
                dispatch_sync(self.managerQueue, ^{
                    if (yesOrNo) {
                        [self.allDownloadRequests addObject:rq];
                    } else {
                        [self.allDownloadRequests insertObject:rq atIndex:0];
                    }
                    [self executeDownloadQueue];
                });
            break;
        }
    }
    });
}

- (BOOL)videoFileValid:(NSString *)filePath
{
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    long long x = [dict[NSFileSize] longLongValue];
    if (x > 100 * 1024) {
        return YES;
    }
    return NO;
}

- (void)dealFailTask:(ZZDownloadTask *)task
{
    task.triedCount += 1;
    task.command = ZZDownloadAssignedCommandStart;
//    task.state = ZZDownloadStateFail;
    task.state = ZZDownloadStateInterrputPaused;
    
    if (task.triedCount > 50) {
        task.state = ZZDownloadStateInvalid;
        task.command = ZZDownloadAssignedCommandNone;
        [self executeDownloadQueue];
        return;
    }
   
    BOOL fifo = NO;
    if (task.triedCount % 5 == 0) {
        fifo = YES;
    }
   
    NSLog(@"i retry%@", task.key);

    ZZDownloadBaseEntity *entity = [task recoverEntity];
    dispatch_async(self.managerQueue, ^{
        [self assignDownloadSectionTask:entity fifo:fifo];
    });
}

- (void)executeDownloadQueue
{
    if (self.allDownloadRequests.count == 0) {
        self.runningOperation = nil;
    }
    if ([[ZZDownloadUrlConnectionQueue shared] operationCount] == 0 && self.allDownloadRequests.count > 0) {
        int x = -1;
        for (int i = 0; i < self.allDownloadRequests.count; i++) {
            ZZDownloadRequestOperation *op = self.allDownloadRequests[i];
            ZZDownloadTask *existedTask = self.allTaskDict[op.key];
            if ([op isPaused] && (existedTask.command != ZZDownloadAssignedCommandStart)) {
                continue;
            } else {
                x = i;
                break;
            }
        }
        if (x != -1) {
            self.runningOperation = self.allDownloadRequests[x];
            if (self.runningOperation) {
                ZZDownloadRequestOperation *op = self.allDownloadRequests[x];
                if (![op isExecuting] && ![op isFinished]) {
                    NSLog(@"task in queue:%@",op.key);
#if BILITEST==1
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[[UIAlertView alloc] initWithTitle:@"下载中" message:op.key delegate:nil cancelButtonTitle:@"quxiao" otherButtonTitles: nil] show];
                    });
#endif
                    [[ZZDownloadUrlConnectionQueue shared] addOperation:self.allDownloadRequests[x]];
                    if ([self.runningOperation isPaused]) {
                        [self.runningOperation resume];
                    }
                }
                [self.allDownloadRequests removeObjectAtIndex:x];
            }
        } else {
            self.runningOperation = nil;
        }
    }
}


- (void)resumeTask:(ZZDownloadTask *)task
{
    int x = -1;
    ZZDownloadRequestOperation *op = nil;
    for (int i = 0; i < self.allDownloadRequests.count; i++) {
         op = self.allDownloadRequests[i];
        if ([op isPaused]) {
            x = i;
            break;
        } else {
            continue;
        }
    }
    if (x != -1) {
        dispatch_async(self.managerQueue, ^{
            [self.allDownloadRequests removeObjectAtIndex:x];
            [self.allDownloadRequests insertObject:op atIndex:0];
            task.command = ZZDownloadAssignedCommandStart;
            task.state = ZZDownloadStateWaiting;
            [self executeDownloadQueue];
        });
    } else {
        NSLog(@"i assign %@", task.key);
        ZZDownloadBaseEntity *entity = [task recoverEntity];
        dispatch_async(self.managerQueue, ^{
            [self assignDownloadSectionTask:entity fifo:NO];
        });
    }
}

- (void)overdueTask:(ZZDownloadTask *)task
{
    if (!task) {
        return;
    }
    task.state = ZZDownloadStateWaiting;
    task.triedCount = 0;
    task.sectionsDownloadedList = [NSMutableArray array];
    task.sectionsLengthList = [NSMutableArray array];
    task.sectionsContentTime = [NSMutableArray array];
    
    ZZDownloadBaseEntity *entity = [task recoverEntity];
    NSString *destinationPath = [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:&error];
    if (error) {
        task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"task:%@ remove fail when over due", task.key], @"originError": error}];
    }
}

- (void)deleteTask:(ZZDownloadTask *)task
{
    if (!task) {
        return;
    }
    ZZDownloadBaseEntity *entity = [task recoverEntity];
    NSString *destinationPath = [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[entity destinationRootDirPath]];
    
    NSString *targtetPath = [[ZZDownloadTaskManager taskFolder] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bilitask", task.key]];
    [[NSFileManager defaultManager] removeItemAtPath:targtetPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
    
    ZZDownloadTask *rtask = self.allTaskDict[task.key];
    if (rtask) {
        rtask.state = ZZDownloadStateRemoved;
        [self notifyQueueRemoveMessage:rtask];
        [rtask removeObserver:[ZZDownloadNotifyManager shared] forKeyPath:@"state" context:ZZDownloadStateChangedContext];
        [self.allTaskDict removeObjectForKey:task.key];
    }
}

- (void)startTask:(ZZDownloadTask *)task fifo:(BOOL)yesOrNo
{
    if (!task || task.command != ZZDownloadAssignedCommandStart || task.state == ZZDownloadStateInvalid) {
        return;
    }
    BOOL scheduled = NO;
    for (ZZDownloadRequestOperation *op in self.allDownloadRequests) {
        if ([task.key isEqualToString:op.key]) {
            scheduled = YES;
            break;
        }
    }
    
    if (scheduled && (task.state == ZZDownloadStateRealPaused || task.state == ZZDownloadStateInterrputPaused)) {
        NSLog(@"i resume %@", task.key);
        [self resumeTask:task];
    } else {
        NSLog(@"i assign %@", task.key);
        ZZDownloadBaseEntity *entity = [task recoverEntity];
        dispatch_async(self.managerQueue, ^{
            [self assignDownloadSectionTask:entity fifo:yesOrNo];
        });
    }

}

- (void)pauseTask:(ZZDownloadTask *)task ukeru:(BOOL)ukeru
{
    if (!task || (task.command != ZZDownloadAssignedCommandPause && task.command != ZZDownloadAssignedCommandInterruptPaused) || task.state == ZZDownloadStateInvalid) {
        return;
    }
    NSLog(@"i stop %@", task.key);
    
    for (ZZDownloadRequestOperation *op in self.allDownloadRequests) {
        if ([op.key isEqualToString:task.key]) {
            [op pause];
        }
    }
    if ([task.key isEqualToString:self.runningOperation.key]) {
        if (![self.runningOperation isPaused] && [self.runningOperation isExecuting]) {
        
        // 由于调pause方法会导致operation堵塞住、然后又需要断点须传所以调用他私有方法更新断点头部
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            if ([self.runningOperation respondsToSelector:@selector(updateByteStartRangeForRequest)]) {
                [self.runningOperation performSelector:@selector(updateByteStartRangeForRequest)];
            }
    #pragma clang diagnostic pop
            // 通过cancel方法触发opertaion的fail
            [self.runningOperation cancel];
        } else {
            if (ukeru) {
                task.state = ZZDownloadStateInterrputPaused;
            } else {
                task.state = ZZDownloadStateRealPaused;
            }
        }
    } else {
        if (ukeru) {
            task.state = ZZDownloadStateInterrputPaused;
        } else {
            task.state = ZZDownloadStateRealPaused;
        }
    }

}

- (void)removeTask:(ZZDownloadTask *)task
{
    if (!task || task.command != ZZDownloadAssignedCommandRemove) {
        return;
    }
    NSLog(@"i remove %@", task.key);
   
    BOOL scheduled = NO;
    NSMutableArray *tmpList = [NSMutableArray array];
    for (ZZDownloadRequestOperation *op in self.allDownloadRequests) {
        if ([op.key isEqualToString:task.key]) {
            [tmpList addObject:op];
        }
    }
    if ([tmpList count] != 0) {
        scheduled = YES;
        dispatch_async(self.managerQueue, ^{
            for (ZZDownloadRequestOperation *op in tmpList) {
                [self.allDownloadRequests removeObject:op];
            }
//            [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
                [self deleteTask:task];
//            }];
        });
    }
    if ([task.key isEqualToString:self.runningOperation.key]) {
        if ([self.runningOperation isExecuting] &&![self.runningOperation isPaused]) {
        // 由于调pause方法会导致operation堵塞住、然后又需要断点须传所以调用他私有方法更新断点头部
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            if ([self.runningOperation respondsToSelector:@selector(updateByteStartRangeForRequest)]) {
                [self.runningOperation performSelector:@selector(updateByteStartRangeForRequest)];
            }
#pragma clang diagnostic pop
            // 通过cancel方法触发opertaion的fail
            [self.runningOperation cancel];
        } else {
            dispatch_async(self.managerQueue, ^{
                [self executeDownloadQueue];
            });
        }
    }
    if (!scheduled) {
        dispatch_async(self.managerQueue, ^{
            [self deleteTask:self.allTaskDict[task.key]];
        });
    }
}

- (void)notifyQueueRemoveMessage:(ZZDownloadTask *)task
{
    ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
    message.key = task.key;
    message.command = ZZDownloadMessageCommandRemoveTaskInfo;
    
    [[ZZDownloadNotifyManager shared] addOp:message];
}

- (void)notifyQueueUpdateMessage:(ZZDownloadTask *)task
{
    ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
    message.key = task.key;
    message.command = ZZDownloadMessageCommandNeedUpdateInfo;
    message.task = task;
   
    [[ZZDownloadNotifyManager shared] addOp:message];
    
    ZZDownloadMessage *message2 = [[ZZDownloadMessage alloc] init];
    message2.key = task.key;
    message2.command = ZZDownloadMessageCommandNeedNotifyUI;
    message2.task = task;
    
    [[ZZDownloadNotifyManager shared] addOp:message2];
}

- (void)watchDog
{
    BOOL x = [self settingCouldDownload];
    if (x != self.couldDownload) {
        if (x) {
            [self resumeAllTask];

        } else {
            [self pauseAllTask];

        }
        NSLog(@"watch dog awake");
        NSLog(@"I found netword changed origin:%d new:%d",self.couldDownload, x);
        NSLog(@"wo!wo!wo!");
        self.couldDownload = x;
        if (self.runningOperation) {
            dispatch_async(self.managerQueue, ^{
                ZZDownloadTask *task = self.allTaskDict[self.runningOperation.key];
                if (task) {
                    task.lastestError =[NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeTransferError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"任务:%@ 网络环境设置无法下载", task.key]}];
                }
            });
        }
    }
    double totalBytes = [[self class] freeDiskSpaceInBytes];
    float mb = totalBytes/1024/1024;
    NSLog(@"remain Bytes: %f", mb);
    if (mb < 300 && mb >= 100) {
        NSLog(@"watch dog awake");
        NSLog(@"warning space warning space warning !");
        NSLog(@"wo!wo!wo!");
        if (self.runningOperation) {
            ZZDownloadMessage *message = [ZZDownloadMessage new];
            message.command = ZZDownloadMessageCommandNotifyDiskWarning;
            [[ZZDownloadNotifyManager shared] addOp:message];
        }
    }
    if (mb < 100) {
        [self pauseAllTask];
        NSLog(@"watch dog awake");
        NSLog(@"error space error space error !");
        NSLog(@"wo!wo!wo!");
        if (self.runningOperation) {
            ZZDownloadMessage *message = [ZZDownloadMessage new];
            message.command = ZZDownloadMessageCommandNotifyDiskBakuhatu;
            [[ZZDownloadNotifyManager shared] addOp:message];
        }
    }
}

+ (double) freeDiskSpaceInBytes{
    struct statfs buf;
    long long freespace = -1;
    if(statfs("/var", &buf) >= 0){
        freespace = (long long)(buf.f_bsize * buf.f_bfree);
    }
    return freespace;
}

- (void)notifyDownloadUpdateMessage
{
    if (!self.runningOperation) {
        return;
    }
    ZZDownloadTask *task = self.allTaskDict[self.runningOperation.key];
    if (!task) {
        return;
    }
    
    [self writeTaskToDisk:task];
    
    ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
    message.key = task.key;
    message.command = ZZDownloadMessageCommandNeedUpdateInfo;
    message.task = task;
    
    [[ZZDownloadNotifyManager shared] addOp:message];
    
    ZZDownloadMessage *message2 = [[ZZDownloadMessage alloc] init];
    message2.key = task.key;
    message2.command = ZZDownloadMessageCommandNeedNotifyUI;
    
    [[ZZDownloadNotifyManager shared] addOp:message2];
//    NSLog(@"~~~~ progress = %f", [task getProgress]);
}

- (void)buildAllTaskInfo
{
    [self.allTaskDict removeAllObjects];
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
        // 清空之前command的状态
        [rtask addObserver:[ZZDownloadNotifyManager shared] forKeyPath:@"state" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:ZZDownloadStateChangedContext];
        rtask.command = ZZDownloadAssignedCommandNone;
        if (rtask.state == ZZDownloadStateDownloading || rtask.state == ZZDownloadStateWaiting) {
            rtask.state = ZZDownloadStateInterrputPaused;
        }
        [self notifyQueueUpdateMessage:rtask];
        if (rtask.key) {
            self.allTaskDict[rtask.key] = rtask;
        }
    }
}

- (void)resumeAllTask
{
    dispatch_async(self.managerQueue, ^{
        __block BOOL dealed = NO;
        [self.allTaskDict enumerateKeysAndObjectsUsingBlock:^(NSString* key, ZZDownloadTask *value, BOOL *stop) {
            if (value.state != ZZDownloadStateInterrputPaused) {
                return;
            }
            dealed = YES;
            ZZDownloadBaseEntity *entity = [value recoverEntity];
            ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
            operation.command = ZZDownloadCommandStart;
            operation.key = [entity entityKey];
            [self addOp:operation withEntity:entity block:nil];
        }];
        if (dealed) {
            ZZDownloadMessage *message = [ZZDownloadMessage new];
            message.command = ZZDownloadMessageCommandNotifyNetworkChangedResume;
            [[ZZDownloadNotifyManager shared] addOp:message];
        }
    });
}

- (void)pauseAllTask
{
    dispatch_async(self.managerQueue, ^{
        [self.allTaskDict enumerateKeysAndObjectsUsingBlock:^(NSString* key, ZZDownloadTask *value, BOOL *stop) {
            ZZDownloadBaseEntity *entity = [value recoverEntity];
            ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
            operation.command = ZZDownloadCommandInterruptStop;
            operation.key = [entity entityKey];
            [self addOp:operation withEntity:entity block:nil];
        }];
    });
    if (self.runningOperation) {
        ZZDownloadMessage *message = [ZZDownloadMessage new];
        message.command = ZZDownloadMessageCommandNotifyNetWorkChangedInterrupt;
        [[ZZDownloadNotifyManager shared] addOp:message];
    }

}

+ (NSArray *)getBiliTaskFileNameList:(NSString *)dirPath suffix:(NSString *)suffix
{
    NSString *taskPath = dirPath;
    NSMutableArray *nameList = [NSMutableArray array];
    if(![[NSFileManager defaultManager] createDirectoryAtPath:taskPath withIntermediateDirectories:YES attributes:nil error:nil]) {
        NSLog(@"Failed to create section directory at %@", taskPath);
    }
    NSArray *tmpList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:taskPath error:nil];
    for (NSString *fileName in tmpList) {
        NSString *fullPath = [taskPath stringByAppendingPathComponent:fileName];
        BOOL x = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&x]) {
            if ([[fileName pathExtension] isEqualToString:suffix]) {
                [nameList addObject:fileName];
            }
        }
    }
    return nameList;
}

+ (NSArray *)getBiliTaskFilePathList
{
    NSString *taskPath = [ZZDownloadTaskManager taskFolder];
    NSMutableArray *nameList = [NSMutableArray array];
    NSArray *tmpList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:taskPath error:nil];
    for (NSString *fileName in tmpList) {
        NSString *fullPath = [taskPath stringByAppendingPathComponent:fileName];
        BOOL x = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&x]) {
            if ([[fileName pathExtension] isEqualToString:@"bilitask"]) {
                [nameList addObject:fullPath];
            }
        }
    }
    return nameList;
}

#pragma mark - Static
+ (NSString *)taskFolder {
    NSFileManager *filemgr = [NSFileManager new];
    static NSString *cacheFolder;
    
    if (!cacheFolder) {
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        cacheFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir];
        NSLog(@"~~~%@", cacheFolder);
    }
    
    // ensure all cache directories are there
    NSError *error = nil;
    if(![filemgr createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Failed to create cache directory at %@", cacheFolder);
        cacheFolder = nil;
    }
    return cacheFolder;
}

+ (NSString *)downloadFolder {
    NSFileManager *filemgr = [NSFileManager new];
    static NSString *cacheFolder;
    
    if (!cacheFolder) {
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        cacheFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskDir];
    }
    
    // ensure all cache directories are there
    NSError *error = nil;
    if(![filemgr createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Failed to create cache directory at %@", cacheFolder);
        cacheFolder = nil;
    }
    return cacheFolder;
}

// calculates the MD5 hash of a key
+ (NSString *)md5StringForString:(NSString *)string {
    const char *str = [string UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (uint32_t)strlen(str), r);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
}

@end
