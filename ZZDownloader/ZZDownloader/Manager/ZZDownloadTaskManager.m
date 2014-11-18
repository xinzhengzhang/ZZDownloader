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
#import "EXTScope.h"
#import "ZZDownloadManager.h"

#define ZZDownloadTaskManagerTaskDir @"zzdownloadtaskmanagertask"
#define ZZDownloadTaskManagerTaskTempDir @"zzdownloadtaskmanagertasktemp"
#define ZZDownloadTaskManagerTaskFileDir @"zzdownloadtaskmanagertaskfile"

@interface ZZDownloadTaskManager ()

@property (nonatomic, strong) NSMutableDictionary *allTaskDict;
@property (nonatomic, strong) NSMutableArray *allDownloadRequests;
@property (nonatomic, strong) ZZDownloadRequestOperation *runningOperation;
@property (nonatomic) dispatch_queue_t managerQueue;
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
        ZZDownloadOperation *op = [[ZZDownloadOperation alloc] init];
        op.command = ZZDownloadCommandBuild;
        [queue doOp:op];
    });
    return queue;
}

- (void)addOp:(ZZDownloadOperation *)operation withEntity:(ZZDownloadBaseEntity *)entity;
{
    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
        [self dealEntity:entity];
        [self doOp:operation];
    }];
}

#pragma mark - internal method
- (void)dealEntity:(ZZDownloadBaseEntity *)entity
{
    NSString *key = [entity entityKey];
    if (!key) {
        return;
    }
    if (self.allTaskDict[key]) {
        return;
    }
    ZZDownloadTask *task = [ZZDownloadTask buildTaskFromDisk:[MTLJSONAdapter JSONDictionaryFromModel:entity]];
    task.key = key;
    task.entityType = NSStringFromClass([entity class]);
    if ([self writeTaskToDisk:task]) {
        self.allTaskDict[key] = task;
    }
}

- (BOOL)writeTaskToDisk:(ZZDownloadTask *)task
{
    NSError *error;
    NSDictionary *dict = [MTLJSONAdapter JSONDictionaryFromModel:task];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        return NO;
    }
    NSString *targtetPath = [[ZZDownloadTaskManager taskFolder] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bilitask", task.key]];
    [jsonData writeToFile:targtetPath options:NSDataWritingAtomic error:&error];
    if (error) {
        return NO;
    }
    return YES;
}

- (void)doOp:(ZZDownloadOperation *)operation
{
    if (operation.command == ZZDownloadCommandBuild) {
        [self buildAllTaskInfo];
        return;
    }
    
    ZZDownloadTask *existedTask = self.allTaskDict[operation.key];
    if (existedTask) {
        @weakify(self);
        switch (operation.command) {
            case ZZDownloadCommandStart:
            {
                [existedTask startWithStartSuccessBlock:^{
                    @strongify(self);
                    [self startTask:existedTask];
                }];
                break;
            }
            case ZZDownloadCommandStop:
            {
                [existedTask pauseWithPauseSuccessBlock:^{
                    @strongify(self);
                    [self pauseTask:existedTask];
                }];
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
            case ZZDownloadCommandCheck:
            {
                ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
                message.command = ZZDownloadMessageCommandNeedNotifyUI;
                [[ZZDownloadNotifyManager shared] addOp:message];
                break;
            }
            default:
                break;
        }
        [self writeTaskToDisk:existedTask];
    } else {
        NSLog(@"warning! unknow task");
    }
}

- (void)assignDownloadSectionTask:(ZZDownloadBaseEntity *)entity
{
    if (!entity || !self.allTaskDict[entity.entityKey]) {
        return;
    }
    ZZDownloadTask *existedTask = self.allTaskDict[entity.entityKey];
    int32_t sectionCount = [entity getSectionCount];
    
    NSString *destinationPath = [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
    
    NSArray *existedFile = [ZZDownloadTaskManager getBiliTaskFileNameList:destinationPath suffix:@"section"];
    for (int i = 0; i < sectionCount; i++) {
        if ([existedFile containsObject:[NSString stringWithFormat:@"%d.section", i]]) {
            if (i == sectionCount-1) {
                existedTask.state = ZZDownloadStateDownloaded;
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
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[entity getSectionUrlWithCount:i]]];
            ZZDownloadRequestOperation *rq = [[ZZDownloadRequestOperation alloc] initWithRequest:request targetPath:targetPath shouldResume:YES];
            rq.key = entity.entityKey;
            
            [rq setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile){
                if (existedTask.command == ZZDownloadAssignedCommandStart) {
                    if (bytesRead > 0) {
                        existedTask.state = ZZDownloadStateDownloading;
                        existedTask.command = ZZDownloadAssignedCommandNone;
                    }
                }
//                NSLog(@"i am %@-%d,my progress = %f", @"", i,totalBytesReadForFile*1.0 / totalBytesExpectedToReadForFile);
            }];
            
            [rq setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                if (operation.response.statusCode >= 200 && operation.response.statusCode < 400) {
                    NSLog(@"i downloaded %@-%d", existedTask.key, i);
                    existedTask.command = ZZDownloadAssignedCommandStart;
                    existedTask.state = ZZDownloadStateWaiting;
                    
                    [self startTask:existedTask];
                } else if (operation.response.statusCode >= 400) {
                    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:NULL];
                    existedTask.triedCount += 1;
                    existedTask.command = ZZDownloadAssignedCommandStart;
                    existedTask.state = ZZDownloadStateFail;
                    
                    if (existedTask.triedCount > 5) {
                        existedTask.state = ZZDownloadStateInvalid;
                        existedTask.command = ZZDownloadAssignedCommandNone;
                    }
                    [self startTask:existedTask];
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error){
                // 暂停一个正在下载的任务也会进这
                NSLog(@"i was interppted %@", existedTask.key);
                if (existedTask.command == ZZDownloadAssignedCommandRemove) {
                    [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
                        [self deleteTask:existedTask];
                    }];
                }
                dispatch_async(self.managerQueue, ^{
                    [self executeDownloadQueue];
                });
            }];
            dispatch_async(self.managerQueue, ^{
                [self.allDownloadRequests insertObject:rq atIndex:0];
                [self executeDownloadQueue];
            });
            break;
        }
    }
}

- (void)executeDownloadQueue
{
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
                [[ZZDownloadUrlConnectionQueue shared] addOperation:self.allDownloadRequests[x]];
                if ([self.runningOperation isPaused]) {
                    [self.runningOperation resume];
                }
                [self.allDownloadRequests removeObjectAtIndex:x];
            }

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
            [self executeDownloadQueue];
        });
    } else {
        NSLog(@"i assign %@", task.key);
        ZZDownloadBaseEntity *entity = [task recoverEntity];
        [self assignDownloadSectionTask:entity];
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
    [self.allTaskDict removeObjectForKey:task.key];
    
    
}

- (void)startTask:(ZZDownloadTask *)task
{
    if (!task || task.command != ZZDownloadAssignedCommandStart || task.state == ZZDownloadStateInvalid) {
        return;
    }
    [self notifyQueueUpdateMessage:task];
    if (task.state == ZZDownloadStatePaused) {
        NSLog(@"i resume %@", task.key);
        [self resumeTask:task];
    } else {
        NSLog(@"i assign %@", task.key);
        ZZDownloadBaseEntity *entity = [task recoverEntity];
        [self assignDownloadSectionTask:entity];
    }

}

- (void)pauseTask:(ZZDownloadTask *)task
{
    if (!task || task.command != ZZDownloadAssignedCommandPause || task.state == ZZDownloadStateInvalid) {
        return;
    }
    [self notifyQueueUpdateMessage:task];
    NSLog(@"i stop %@", task.key);
    
    for (ZZDownloadRequestOperation *op in self.allDownloadRequests) {
        if ([op.key isEqualToString:task.key]) {
            [op pause];
        }
    }
    if ([task.key isEqualToString:self.runningOperation.key]) {
        // 由于调pause方法会导致operation堵塞住、然后又需要断点须传所以调用他私有方法更新断点头部
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if ([self.runningOperation respondsToSelector:@selector(updateByteStartRangeForRequest)]) {
            [self.runningOperation performSelector:@selector(updateByteStartRangeForRequest)];
        }
#pragma clang diagnostic pop
        // 通过cancel方法触发opertaion的fail
        [self.runningOperation cancel];
    }
    
    task.state = ZZDownloadStatePaused;
    task.command = ZZDownloadAssignedCommandNone;
}

- (void)removeTask:(ZZDownloadTask *)task
{
    if (!task || task.command != ZZDownloadAssignedCommandRemove) {
        return;
    }
    [self notifyQueueUpdateMessage:task];
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
            [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
                [self deleteTask:task];
            }];
        });
    }
    if ([task.key isEqualToString:self.runningOperation.key]) {
        scheduled = YES;
        // 由于调pause方法会导致operation堵塞住、然后又需要断点须传所以调用他私有方法更新断点头部
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if ([self.runningOperation respondsToSelector:@selector(updateByteStartRangeForRequest)]) {
            [self.runningOperation performSelector:@selector(updateByteStartRangeForRequest)];
        }
#pragma clang diagnostic pop
        // 通过cancel方法触发opertaion的fail
        [self.runningOperation cancel];
    }
    if (!scheduled) {
        [[ZZDownloadOpQueue shared] addOperationWithBlock:^{
            [self deleteTask:self.allTaskDict[task.key]];
        }];
    }



    
    
    // remove download queue
}

- (void)notifyQueueUpdateMessage:(ZZDownloadTask *)task
{
    ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
    message.key = task.key;
    message.command = ZZDownloadMessageCommandNeedUpdateInfo;
    message.task = task;
   
    ZZDownloadMessage *message2 = [[ZZDownloadMessage alloc] init];
    message.key = task.key;
    message.command = ZZDownloadMessageCommandNeedNotifyUI;
    
    [[ZZDownloadNotifyManager shared] addOp:message];
    [[ZZDownloadNotifyManager shared] addOp:message2];
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
        rtask.command = ZZDownloadAssignedCommandNone;
        if (rtask.key) {
            self.allTaskDict[rtask.key] = rtask;
        }
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

+ (NSString *)cacheFolder {
    NSFileManager *filemgr = [NSFileManager new];
    static NSString *cacheFolder;
    
    if (!cacheFolder) {
        NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        cacheFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskTempDir];
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
