//
//  ZZDownloadTaskManagerV2.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 12/15/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloadTaskManagerV2.h"
#import "ZZDownloadTask.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadTaskGroupManager.h"
#import "Reachability.h"
#import "ZZDownloadUrlConnectionQueue.h"
#import "ZZDownloadTaskCFNetworkOperation.h"
#import "ZZDownloadTask+Helper.h"
#import "ZZDownloader.h"

#define ZZDownloadOpQueueName @"ZZDownloadOpThread"
@interface ZZDownloadTaskManagerV2 () <ZZDownloadTaskOperationDelegate>

@property (nonatomic) NSMutableDictionary *allTaskDict;
@property (nonatomic) BOOL couldDownload;
@property (nonatomic, copy) void (^CFCompleteBlock)(NSString *key);
@property (nonatomic) NSThread *opThread;
@property (nonatomic) NSSet *runLoopModes;

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
        manager.opThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [manager.opThread start];
        manager.runLoopModes = [NSSet setWithObject:NSRunLoopCommonModes];
        
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        if(![[NSFileManager defaultManager] createDirectoryAtPath:[cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir] withIntermediateDirectories:YES attributes:nil error:nil]) {
            NSLog(@"Failed to create section directory at %@", ZZDownloadTaskManagerTaskFileDir);
        }
        
        if(![[NSFileManager defaultManager] createDirectoryAtPath:[cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir] withIntermediateDirectories:YES attributes:nil error:nil]) {
            NSLog(@"Failed to create section directory at %@", ZZDownloadTaskManagerTaskDir);
        }
        
        
        manager.CFCompleteBlock = ^(NSString *key){
            [manager performSelector:@selector(taskCompleteCallBackHandler:) onThread:manager.opThread withObject:key waitUntilDone:YES modes:[manager.runLoopModes allObjects]];
        };
        ZZDownloadOperation *bop = [ZZDownloadOperation new];
        bop.command = ZZDownloadCommandBuild;
        [manager addOp:bop withEntity:nil block:nil];
        
    });
    return manager;
}

- (void)taskCompleteCallBackHandler:(NSString *)key
{
    ZZDownloadTask *task = self.allTaskDict[key];
    if (task.state == ZZDownloadStateDownloaded) {
        [self executeOperationByWeight];
        [self writeTaskToDisk:task];
        [self notifyQueueUpdateMessage:task];
    } else if (task.command == ZZDownloadAssignedCommandRemove){
        [self deleteTask:key];
        [self executeOperationByWeight];
    } else if (task.command == ZZDownloadAssignedCommandPause) {
        task.state = ZZDownloadStateRealPaused;
        task.command = ZZDownloadAssignedCommandNone;
        task.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
        [self executeOperationByWeight];
        [self writeTaskToDisk:task];
        [self notifyQueueUpdateMessage:task];
    }else if (task.command == ZZDownloadAssignedCommandInterruptPaused) {
        task.state = ZZDownloadStateInterrputPaused;
        task.command = ZZDownloadAssignedCommandNone;
        task.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
        [self executeOperationByWeight];
        [self writeTaskToDisk:task];
        [self notifyQueueUpdateMessage:task];
    } else {
        if (task.taskArrangeType == ZZDownloadTaskArrangeTypeUnArranged) {
            return ;
        } else {
            task.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
            [self dealFailTask:task.key];
            [self writeTaskToDisk:task];
            [self notifyQueueUpdateMessage:task];
        }
    }
}

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:ZZDownloadOpQueueName];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
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

- (void)checkSelfUnSecheduledWorkKey:(NSString *)key block:(void(^)(id))block

{
    ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
    operation.command  = ZZDownloadCommandStartCache;
    operation.key = key;
    
    [self addOp:operation withEntity:nil block:block];
}

- (void)addOp:(ZZDownloadOperation *)operation withEntity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{@"op": operation}];
    if (entity) dict[@"entity"] = entity;
    if (block) dict[@"block"] = block;
    [self performSelector:@selector(doOpWrap:) onThread:self.opThread withObject:dict waitUntilDone:NO modes:[self.runLoopModes allObjects]];
}

- (void)doOpWrap:(NSDictionary *)wrap
{
    NSAssert(wrap[@"op"], @"opWrap error");
    [self doOp:wrap[@"op"] entity:wrap[@"entity"] block:wrap[@"block"]];
}

- (void)doOp:(ZZDownloadOperation *)operation entity:(ZZDownloadBaseEntity *)entity block:(void (^)(id))block
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
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
    if (operation.command == ZZDownloadCommandStartCache) {
        [self executeBackgroundTaskByWeightDefaultKey:operation.key block:^(NSNumber *number){
            if (block) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(number);
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
            ZZDownloadMessage *message = [ZZDownloadMessage new];
            message.command = ZZDownloadMessageCommandNotifyStartTaskUnderCelluar;
            [[ZZDownloadNotifyManager shared] addOp:message];
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
    NSArray *filePathList = [self getTaskFilePathList];
    NSError *error;
    for (NSString *filePath in filePathList) {
        NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
        if (error || !data) {
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
        
        if (rtask.key) {
            self.allTaskDict[rtask.key] = rtask;
            [self dealBgCache:rtask];
            if (rtask.state == ZZDownloadStateDownloading || rtask.state == ZZDownloadStateParsing || rtask.state == ZZDownloadStateWaiting) {
                rtask.state = ZZDownloadStateNothing;
                rtask.command = ZZDownloadAssignedCommandStart;
            }
            [self notifyQueueUpdateMessage:rtask];
        }
    }
}

- (void)dealBgCache:(ZZDownloadTask *)task
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    ZZDownloadBaseEntity *entity = [task recoverEntity];
    if (entity.uniqueKey && entity.sections) {
        int sections = entity.sections;
        for (int i = 0; i < sections; i++) {
            NSString *tempBgCache = [self bgCachedPathKey:task.key index:i uniqueKey:entity.uniqueKey isLast:i == sections];
            if (!tempBgCache) {
                return;
            }
            NSString *destinationPath = [[self.class downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
            if(![[NSFileManager defaultManager] createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:nil]) {
                NSLog(@"Failed to create section directory at %@", destinationPath);
            }
            destinationPath = [destinationPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.section", i]];
            NSError *fileE;
            [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
            [[NSFileManager defaultManager] moveItemAtPath:tempBgCache toPath:destinationPath error:&fileE];
            if (fileE) {
                task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey:@"文件缓存移动错误"}];
                return;
            } else {
                if (task.sectionsLengthList.count > i) {
                    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:destinationPath error:nil];
                    long long x = [dict[NSFileSize] longLongValue];
                    task.sectionsLengthList[i] = [NSNumber numberWithUnsignedInteger:x];
                }
            }
        }
    } else {
        return;
    }
    task.state = ZZDownloadStateDownloaded;
    task.lastestError = nil;
    task.command = ZZDownloadAssignedCommandNone;
    [self writeTaskToDisk:task];
    [self notifyQueueUpdateMessage:task];
}

- (NSString *)bgCachedPathKey:(NSString *)key index:(int32_t)index uniqueKey:(NSString *)uniquekey isLast:(BOOL)isLast
{
    NSString *targetPath = [ZZDownloadTaskCFNetworkOperation getBackgroundDownloadTempPath:key section:index typetag:uniquekey];
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:targetPath error:nil];
    long long x = [dict[NSFileSize] longLongValue];
    NSInteger kb = isLast ? 10 : 100;
    if (x > kb * 1024) {
        return targetPath;
    }
    return nil;
}

- (void)updateTaskByEntity:(ZZDownloadBaseEntity *)entity
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    NSString *key = [entity entityKey];
    if (!key) {
        return;
    }
    NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
        return (NSComparisonResult)(task1.weight > task2.weight);
    }];
    if (!self.allTaskDict[key]) {
        ZZDownloadTask *task = [ZZDownloadTask buildTaskFromDisk:[MTLJSONAdapter JSONDictionaryFromModel:entity]];
        task.key = key;
        task.entityType = NSStringFromClass([entity class]);
        
        if (keys.count) {
            task.weight = [self.allTaskDict[keys.lastObject] weight] + 1;
        }
        [task addObserver:[ZZDownloadNotifyManager shared] forKeyPath:@"state" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:ZZDownloadStateChangedContext];
        [self notifyQueueUpdateMessage:task];
        self.allTaskDict[key] = task;
    } else {
        if (keys.count) {
            ZZDownloadTask *task = self.allTaskDict[key];
            task.weight = [self.allTaskDict[keys.firstObject] weight] - 1;
        }
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
    
    NSString *targtetPath = [taskFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.task", task.key]];
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

-(void)executeBackgroundTaskByWeightDefaultKey:(NSString *)taskKey block:(void (^)(NSNumber *))block
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    //    if (addCount <= 2) {
    if (taskKey && self.allTaskDict[taskKey]) {
        [self dealBgCache:self.allTaskDict[taskKey]];
    } else {
        [self.allTaskDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, ZZDownloadTask *task, BOOL *stop) {
            if (task.state == ZZDownloadStateDownloaded || task.taskArrangeType != ZZDownloadTaskArrangeTypeUnArranged) {
                return;
            }
            [self dealBgCache:task];
        }];
    }
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
            return (NSComparisonResult)(task1.weight < task2.weight);
        }];
        NSMutableArray *tempArray = [NSMutableArray array];
        
        [keys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger index, BOOL *stop) {
            ZZDownloadTask *task = self.allTaskDict[key];
            if (task && [self taskCanStartDownload:task]) {
                [self dealBgCache:task];
                if (task.state == ZZDownloadStateDownloaded) {
                    return;
                }
                [tempArray addObject:task];
                if (tempArray.count > 10) {
                    *stop = YES;
                }
            }
        }];
        [[ZZDownloadBackgroundSessionManager shared] addCacheTaskByTasks:tempArray completionBlock:block];
    }
}

- (void)executeOperationByWeight
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    NSArray *opQ = [[ZZDownloadUrlConnectionQueue shared] operations];
    NSInteger runningCount = opQ.count;
    for (ZZDownloadTaskCFNetworkOperation *op in opQ) {
        if (op.state == ZZTaskOperationStateFinish) {
            runningCount -= 1;
        }
    }
    if (runningCount < [[ZZDownloadUrlConnectionQueue shared] maxConcurrentOperationCount]) {
        NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
            return (NSComparisonResult)(task1.weight > task2.weight);
        }];
        [keys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger index, BOOL *stop){
            __block ZZDownloadTask *task = self.allTaskDict[key];
            if (task && [self taskCanStartDownload:task]) {
                if (![self settingCouldDownload]) {
                    *stop = YES;
                    return;
                }
                task.taskArrangeType = ZZDownloadTaskArrangeTypeCFSync;
                NSLog(@"start task=%@",task.key);
                ZZDownloadTaskCFNetworkOperation *op = [[ZZDownloadTaskCFNetworkOperation alloc] initWithTask:task];
                op.delegate = self;
                op.completionBlock = ^{
                    self.CFCompleteBlock(task.key);
                };
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
    NSLog(@"task=%@ failcount=%d",key, task.triedCount);
    if (task.triedCount > 10 || (task.lastestError && task.lastestError.code == ZZDownloadTaskErrorTypeIOFullError)) {
        task.state = ZZDownloadStateInvalid;
        task.command = ZZDownloadAssignedCommandNone;
        [self executeOperationByWeight];
        return;
    }
    
    if (task.triedCount % 2 == 0) {
        NSArray *keys = [self.allTaskDict keysSortedByValueUsingComparator:^(ZZDownloadTask *task1, ZZDownloadTask *task2) {
            return (NSComparisonResult)(task1.weight > task2.weight);
        }];
        task.weight = [self.allTaskDict[keys.lastObject] weight] + 1;
        [self executeOperationByWeight];
    } else {
        [self executeOperationByKey:task.key];
    }
}

- (void)executeOperationByKey:(NSString *)key
{
    ZZDownloadQueueAssert(ZZDownloadOpQueueName);
    
    NSArray *opQ = [[ZZDownloadUrlConnectionQueue shared] operations];
    NSInteger runningCount = opQ.count;
    for (ZZDownloadTaskCFNetworkOperation *op in opQ) {
        if (op.state == ZZTaskOperationStateFinish) {
            runningCount -= 1;
        }
    }
    if (runningCount < [[ZZDownloadUrlConnectionQueue shared] maxConcurrentOperationCount]) {
        ZZDownloadTask *task = self.allTaskDict[key];
        if (task && [self taskCanStartDownload:task]) {
            if (![self settingCouldDownload]) {
                return;
            }
            task.taskArrangeType = ZZDownloadTaskArrangeTypeCFSync;
            ZZDownloadTaskCFNetworkOperation *op = [[ZZDownloadTaskCFNetworkOperation alloc] initWithTask:task];
            op.delegate = self;
            op.completionBlock = ^{
                self.CFCompleteBlock(task.key);
            };
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
    
    NSString *targtetPath = [taskFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.task", task.key]];
    [jsonData writeToFile:targtetPath options:NSDataWritingAtomic error:&error];
    if (error) {
        task.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"task:%@ write to file fail", task.key], @"originError": error}];
        return NO;
    }
    return YES;
}

- (NSArray *)getTaskFilePathList
{
    NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *taskPath = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDir];
    NSMutableArray *nameList = [NSMutableArray array];
    NSArray *tmpList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:taskPath error:nil];
    for (NSString *fileName in tmpList) {
        NSString *fullPath = [taskPath stringByAppendingPathComponent:fileName];
        BOOL x = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&x]) {
            if ([[fileName pathExtension] isEqualToString:@"task"]) {
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
    Reachability* curReach = [Reachability reachabilityWithHostName:@"www.baidu.com"];
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
    if ([[[NSThread currentThread] name] isEqualToString:self.opThread.name]) {
        block();
    } else {
        [self performSelector:@selector(updateTaskWithBlock:) onThread:self.opThread withObject:block waitUntilDone:YES modes:[self.runLoopModes allObjects]];
    }
}

- (void)notifyUpdate:(NSString *)key
{
    ZZDownloadTask *task = self.allTaskDict[key];
    if (!task) return;
    [self performSelector:@selector(writeTaskToDisk:) onThread:self.opThread withObject:task waitUntilDone:YES modes:[self.runLoopModes allObjects]];
    
    [self notifyQueueUpdateMessage:task];
}

@end
