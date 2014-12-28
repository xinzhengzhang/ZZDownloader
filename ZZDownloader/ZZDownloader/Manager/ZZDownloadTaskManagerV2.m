//
//  ZZDownloadTaskManagerV2.m
//  ibiliplayer
//
//  Created by zhangxinzheng on 12/15/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloadTaskManagerV2.h"
#import "ZZDownloadTask.h"
#import "ZZDownloadOpQueue.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadTaskGroupManager.h"
#import "Reachability.h"
#import "ZZDownloadUrlConnectionQueue.h"
//#import "ZZdownloadTaskBackgroundOperation.h"
#import "ZZDownloadTaskCFNetworkOperation.h"
#import "ZZDownloadTask+Helper.h"
#import "ZZDownloader.h"

@interface ZZDownloadTaskManagerV2 () <ZZDownloadTaskOperationDelegate>

@property (nonatomic) NSMutableDictionary *allTaskDict;
@property (nonatomic) BOOL couldDownload;
@property (nonatomic, copy) void (^CFCompleteBlock)(NSString *key);
@property (nonatomic, copy) void (^t)();
@end

@implementation ZZDownloadTaskManagerV2

+ (id)shared
{
    static ZZDownloadTaskManagerV2 *manager;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        manager = [ZZDownloadTaskManagerV2 new];
        manager.allTaskDict = [NSMutableDictionary dictionary];
        manager.couldDownload = YES;
        
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        if(![[NSFileManager defaultManager] createDirectoryAtPath:[cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir] withIntermediateDirectories:YES attributes:nil error:nil]) {
            NSLog(@"Failed to create section directory at %@", ZZDownloadTaskManagerTaskFileDir);
        }
        
        if(![[NSFileManager defaultManager] createDirectoryAtPath:[cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir] withIntermediateDirectories:YES attributes:nil error:nil]) {
            NSLog(@"Failed to create section directory at %@", ZZDownloadTaskManagerTaskDir);
        }
        
        __weak __typeof(manager)weakSelf = manager;
        
        manager.CFCompleteBlock = ^(NSString *key){
            [[ZZDownloadOpQueue shared] addOperationWithBlock: ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                
                ZZDownloadTask *task = strongSelf.allTaskDict[key];
                if (task.state == ZZDownloadStateDownloaded) {
                    [manager executeOperationByWeight];
                    [manager writeTaskToDisk:task];
                    [manager notifyQueueUpdateMessage:task];
                } else if (task.command == ZZDownloadAssignedCommandRemove){
                    [manager deleteTask:key];
                    [manager executeOperationByWeight];
                } else if (task.command == ZZDownloadAssignedCommandPause) {
                    task.state = ZZDownloadStateRealPaused;
                    task.command = ZZDownloadAssignedCommandNone;
                    task.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
                    [manager executeOperationByWeight];
                    [manager writeTaskToDisk:task];
                    [manager notifyQueueUpdateMessage:task];
                }else if (task.command == ZZDownloadAssignedCommandInterruptPaused) {
                    task.state = ZZDownloadStateInterrputPaused;
                    task.command = ZZDownloadAssignedCommandNone;
                    task.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
                    [manager executeOperationByWeight];
                    [manager writeTaskToDisk:task];
                    [manager notifyQueueUpdateMessage:task];
                } else {
                    if (task.taskArrangeType == ZZDownloadTaskArrangeTypeUnArranged) {
                        return ;
                    } else {
                        task.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
                        [manager dealFailTask:task.key];
                        [manager writeTaskToDisk:task];
                        [manager notifyQueueUpdateMessage:task];
                    }
                    
                }
            }];
        };
        ZZDownloadOperation *bop = [ZZDownloadOperation new];
        bop.command = ZZDownloadCommandBuild;
        [manager addOp:bop withEntity:nil block:nil];
        
    });
    return manager;
}

- (BOOL)isDownloading
{
    return [[ZZDownloadUrlConnectionQueue shared] operationCount] != 0;
}

+ (NSString *)downloadFolder
{
    static NSString *downloadFolder;
    if (!downloadFolder) {
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        downloadFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskDir];
    }
    
    return downloadFolder;
}

- (void)checkSelfUnSecheduledWork:(void (^)(id))block
{
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command  = ZZDownloadCommandCheckSelfUnSecheduledTask;
    
    [self addOp:operation withEntity:nil block:block];
}

- (void)addOp:(ZZDownloadOperation *)operation withEntity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block
{
    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
        [self doOp:operation entity:entity block:block];
    }];
}
- (void)doOp:(ZZDownloadOperation *)operation entity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    //    NSLog(@"do op operation=%u key=%@", operation.command, operation.key);
    if (operation.command == ZZDownloadCommandBuild) {
        [self buildAllTaskInfo];
        [self executeOperationByWeight];
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
    if (operation.command == ZZDownloadCommandCheckSelfUnSecheduledTask) {
        [self executeBackgroundTaskByWeight:^{
            if (block) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(nil);
                });
            }
        }];
        return;
    }
    if (operation.command == ZZDownloadCommandStart) {
        [self updateTaskByEntity:entity];
        if ([self settingCouldDownload]) {
            [self startDownloadTask:operation.key];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"网络设置异常" message:@"如需在蜂窝下开启下载请在设置中勾选> <" delegate:nil cancelButtonTitle:@"知道啦" otherButtonTitles:nil] show];
            });
        }
        return;
    }
    if (operation.command == ZZDownloadCommandStop) {
        [self pauseDownloadTask:operation.key];
        return;
    }
    if (operation.command == ZZDownloadCommandRemove) {
        [self removeDownloadTask:operation.key];
        return;
    }
    if (operation.command == ZZDownloadCommandInterruptStop) {
        [self interruptPauseDownloadTask:operation.key];
    }
}

#pragma mark -
- (void)buildAllTaskInfo
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    [self.allTaskDict removeAllObjects];
    NSArray *filePathList = [self getBiliTaskFilePathList];
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
        [rtask addObserver:[ZZDownloadNotifyManager shared] forKeyPath:@"state" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:ZZDownloadStateChangedContext];
        rtask.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
        //        rtask.command = ZZDownloadAssignedCommandNone;
        
        [self notifyQueueUpdateMessage:rtask];
        if (rtask.key) {
            self.allTaskDict[rtask.key] = rtask;
        }
        if (rtask.state == ZZDownloadStateDownloading) {
            rtask.state = ZZDownloadStateNothing;
            rtask.command = ZZDownloadAssignedCommandStart;
            NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
                return (NSComparisonResult)(task1.weight > task2.weight);
            }];
            if (keys.count) {
                rtask.weight = [self.allTaskDict[keys.firstObject] weight] -1;
            }
        }
    }
}

- (void)updateTaskByEntity:(ZZDownloadBaseEntity *)entity
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    NSString *key = [entity entityKey];
    if (!key) {
        return;
    }
    if (!self.allTaskDict[key]) {
        ZZDownloadTask *task = [ZZDownloadTask buildTaskFromDisk:[MTLJSONAdapter JSONDictionaryFromModel:entity]];
        task.key = key;
        task.entityType = NSStringFromClass([entity class]);
        NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
            return (NSComparisonResult)(task1.weight > task2.weight);
        }];
        if (keys.count) {
            task.weight = [self.allTaskDict[keys.firstObject] weight] - 1;
        }
        [task addObserver:[ZZDownloadNotifyManager shared] forKeyPath:@"state" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:ZZDownloadStateChangedContext];
        [self notifyQueueUpdateMessage:task];
        self.allTaskDict[key] = task;
    }
}

- (void)startDownloadTask:(NSString *)key
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) return;
    [task startWithStartSuccessBlock:^{
        [self executeOperationByWeight];
    }];
    [self writeTaskToDisk:task];
    [self notifyQueueUpdateMessage:task];
    
}

- (void)pauseDownloadTask:(NSString *)key
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) return;
    [task pauseWithPauseSuccessBlock:^{
        if (task.taskArrangeType == ZZDownloadTaskArrangeTypeUnArranged) {
            task.state = ZZDownloadStateRealPaused;
            task.command = ZZDownloadAssignedCommandNone;
        } else if (task.taskArrangeType == ZZDownloadTaskArrangeTypeCFSync) {
            NSArray *tmpOp = [[ZZDownloadUrlConnectionQueue shared] operations];
            for (ZZDownloadTaskCFNetworkOperation *op in tmpOp) {
                if ([op.key isEqualToString:key]) {
                    //                    [op cancel];
                    [op pause];
                }
            }
        }
    } ukeru:NO];
    [self writeTaskToDisk:task];
    [self notifyQueueUpdateMessage:task];
}

- (void)interruptPauseDownloadTask:(NSString *)key
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) return;
    [task pauseWithPauseSuccessBlock:^{
        if (task.taskArrangeType == ZZDownloadTaskArrangeTypeUnArranged) {
            task.state = ZZDownloadStateInterrputPaused;
            task.command = ZZDownloadAssignedCommandNone;
        } else if (task.taskArrangeType == ZZDownloadTaskArrangeTypeCFSync) {
            NSArray *tmpOp = [[ZZDownloadUrlConnectionQueue shared] operations];
            for (ZZDownloadTaskCFNetworkOperation *op in tmpOp) {
                if ([op.key isEqualToString:key]) {
                    [op cancel];
                }
            }
        }
    } ukeru:YES];
    [self writeTaskToDisk:task];
    [self notifyQueueUpdateMessage:task];
}

- (void)removeDownloadTask:(NSString *)key
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) return;
    [task removeWithRemoveSuccessBlock:^{
        NSArray *ops = [[ZZDownloadUrlConnectionQueue shared] operations];
        BOOL inQueue = NO;
        for (ZZDownloadTaskCFNetworkOperation *op in ops) {
            if ([op.key isEqualToString:key]) {
                inQueue = YES;
                //                [op cancel];
                [op remove];
                break;
            }
        }
        if (!inQueue) {
            [self deleteTask:task.key];
        }
    }];
}

- (void)deleteTask:(NSString *)key {
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) {
        return;
    }
    ZZDownloadBaseEntity *entity = [task recoverEntity];
    NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *downloadFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskDir];
    NSString *destinationPath = [downloadFolder stringByAppendingPathComponent:[entity destinationRootDirPath]];
    NSString *taskFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir];
    
    NSString *targtetPath = [taskFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bilitask", task.key]];
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

- (void)resumeAllTask
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
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
}

- (void)pauseAllTask
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    if (self.isDownloading) {
        ZZDownloadMessage *message = [ZZDownloadMessage new];
        message.command = ZZDownloadMessageCommandNotifyNetWorkChangedInterrupt;
        [[ZZDownloadNotifyManager shared] addOp:message];
    }
    [self.allTaskDict enumerateKeysAndObjectsUsingBlock:^(NSString* key, ZZDownloadTask *value, BOOL *stop) {
        ZZDownloadBaseEntity *entity = [value recoverEntity];
        ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
        operation.command = ZZDownloadCommandInterruptStop;
        operation.key = [entity entityKey];
        [self doOp:operation entity:entity block:nil];
    }];
}

-(void)executeBackgroundTaskByWeight:(void (^)(void))block
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    //    __block int32_t addCount = [[ZZDownloadBackgroundSessionManager shared] bgCachedCount];
    //    if (addCount <= 2) {
    __block int32_t addCount = 0;
    NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
        return (NSComparisonResult)(task1.weight > task2.weight);
    }];
    [keys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger index, BOOL *stop) {
        ZZDownloadTask *task = self.allTaskDict[key];
        if (task && [self taskCanStartDownload:task]) {
            int32_t added = [[ZZDownloadBackgroundSessionManager shared] addCacheTaskByTask:task];
            [self writeTaskToDisk:task];
            addCount += added;
            if (addCount > 5) {
                *stop = YES;
            }
        }
    }];
    //    }
    if (block) {
        block();
    }
}

- (void)executeOperationByWeight
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    if ([[ZZDownloadUrlConnectionQueue shared] operationCount] < [[ZZDownloadUrlConnectionQueue shared] maxConcurrentOperationCount]) {
        NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
            return (NSComparisonResult)(task1.weight > task2.weight);
        }];
        [keys enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString *key, NSUInteger index, BOOL *stop){
            __block ZZDownloadTask *task = self.allTaskDict[key];
            if (task && [self taskCanStartDownload:task]) {
                if (![self settingCouldDownload]) {
                    //                    task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey: @"network not in wifi"}];
                    *stop = YES;
                    return;
                }
                task.taskArrangeType = ZZDownloadTaskArrangeTypeCFSync;
                ZZDownloadTaskCFNetworkOperation *op = [[ZZDownloadTaskCFNetworkOperation alloc] initWithTask:task];
                op.delegate = self;
                op.completionBlock = ^{
                    self.CFCompleteBlock(task.key);
                };
                //                [[ZZDownloadUrlConnectionQueue shared] addOperation:op];
                [[ZZDownloadUrlConnectionQueue shared] addOperations:@[op] waitUntilFinished:NO];
                if ([[ZZDownloadUrlConnectionQueue shared] operationCount] >= [[ZZDownloadUrlConnectionQueue shared] maxConcurrentOperationCount]) {
                    *stop = YES;
                }
            }
        }];
    }
}

- (BOOL)taskCanStartDownload:(ZZDownloadTask *)task
{
    BOOL valid = YES;
    if (task.state == ZZDownloadStateDownloaded) {
        valid = NO;
    }
    if (task.taskArrangeType != ZZDownloadTaskArrangeTypeUnArranged) {
        valid = NO;
    }
    if (task.state == ZZDownloadStateRealPaused) {
        valid = NO;
    }
    if (task.state == ZZDownloadStateInvalid) {
        valid = NO;
    }
    if (task.state == ZZDownloadStateInterrputPaused ) {
        valid = NO;
    }
    if (task.command != ZZDownloadAssignedCommandStart) {
        valid = NO;
    }
    return valid;
}

- (void)dealFailTask:(NSString *)key
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) return;
    task.triedCount += 1;
    task.command = ZZDownloadAssignedCommandStart;
    task.state = ZZDownloadStateFail;
    
    if (task.triedCount > 10) {
        task.state = ZZDownloadStateInvalid;
        task.command = ZZDownloadAssignedCommandNone;
        [self executeOperationByWeight];
        return;
    }
    
    if (task.triedCount % 2 == 0) {
        task.weight = 1;
        [self executeOperationByWeight];
    } else {
        [self executeOperationByKey:task.key];
    }
}

- (void)executeOperationByKey:(NSString *)key
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    if ([[ZZDownloadUrlConnectionQueue shared] operationCount] < [[ZZDownloadUrlConnectionQueue shared] maxConcurrentOperationCount]) {
        ZZDownloadTask *task = self.allTaskDict[key];
        if (task && [self taskCanStartDownload:task]) {
            if (![self settingCouldDownload]) {
                //                task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey: @"network not in wifi"}];
                return;
            }
            task.taskArrangeType = ZZDownloadTaskArrangeTypeCFSync;
            ZZDownloadTaskCFNetworkOperation *op = [[ZZDownloadTaskCFNetworkOperation alloc] initWithTask:task];
            op.delegate = self;
            op.completionBlock = ^{
                self.CFCompleteBlock(task.key);
            };
            //            [[ZZDownloadUrlConnectionQueue shared] addOperation:op];
            [[ZZDownloadUrlConnectionQueue shared] addOperations:@[op] waitUntilFinished:NO];
            
        }
    }
}

#pragma mark - tools
- (BOOL)writeTaskToDisk:(ZZDownloadTask *)task
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    NSError *error;
    NSDictionary *dict = [MTLJSONAdapter JSONDictionaryFromModel:task];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeTransferError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"task:%@ data transfer to dict fail", task.key], @"originError": error}];
        return NO;
    }
    NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *taskFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir];
    
    NSString *targtetPath = [taskFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bilitask", task.key]];
    [jsonData writeToFile:targtetPath options:NSDataWritingAtomic error:&error];
    if (error) {
        task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"task:%@ write to file fail", task.key], @"originError": error}];
        return NO;
    }
    return YES;
}

- (NSArray *)getBiliTaskFilePathList
{
    NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *taskPath = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir];
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

- (void)setEnableDownloadUnderWWAN:(BOOL)enableDownloadUnderWWAN
{
    if (_enableDownloadUnderWWAN != enableDownloadUnderWWAN) {
        _enableDownloadUnderWWAN = enableDownloadUnderWWAN;
    }
}

- (BOOL)settingCouldDownload
{
    if (self.enableDownloadUnderWWAN) {
        return YES;
    }
    Reachability* curReach = [Reachability reachabilityWithHostname:@"www.baidu.com"];
    NetworkStatus status = [curReach currentReachabilityStatus];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    if (status == NotReachable) {
        return NO;
    }
    else if (status == ReachableViaWiFi) {
        return YES;
    }
    else if (status == ReachableViaWWAN) {
        return NO;
    }
    return NO;
}

- (void)notifyQueueUpdateMessage:(ZZDownloadTask *)task
{
    ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
    message.key = task.key;
    message.command = ZZDownloadMessageCommandNeedUpdateInfo;
    message.task = [task deepCopy];
    
    [[ZZDownloadNotifyManager shared] addOp:message];
    
    ZZDownloadMessage *message2 = [[ZZDownloadMessage alloc] init];
    message2.key = task.key;
    message2.command = ZZDownloadMessageCommandNeedNotifyUI;
    message2.task = task;
    
    [[ZZDownloadNotifyManager shared] addOp:message2];
}

- (void)notifyQueueRemoveMessage:(ZZDownloadTask *)task
{
    ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
    message.key = task.key;
    message.command = ZZDownloadMessageCommandRemoveTaskInfo;
    
    [[ZZDownloadNotifyManager shared] addOp:message];
}

#pragma mark - cfOperation delegate
- (void)updateTaskWithBlock:(void (^)())block
{
    NSCondition *condit = [NSCondition new];
    __block volatile BOOL dealed = NO;
    
    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
        block();
        [condit lock];
        dealed = YES;
        [condit signal];
        [condit unlock];
    }];
    
    [condit lock];
    while (!dealed) {
        [condit waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    [condit unlock];
    
}

- (void)notifyUpdate:(NSString *)key
{
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) return;
    ZZDownloadTask *t = task;
    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
        [self writeTaskToDisk:t];
    }];
    [self notifyQueueUpdateMessage:t];
}

@end
