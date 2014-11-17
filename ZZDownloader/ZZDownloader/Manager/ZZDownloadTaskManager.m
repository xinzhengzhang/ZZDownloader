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
#import "AFDownloadRequestOperation.h"
#import "ZZDownloadUrlConnectionQueue.h"
#import "ZZDownloadTask+Helper.h"
#import <objc/runtime.h>
#import "EXTScope.h"
#import "ZZDownloadManager.h"

#define ZZDownloadTaskManagerTaskDir @"zzdownloadtaskmanagertask"
#define ZZDownloadTaskManagerTaskTempDir @"zzdownloadtaskmanagertasktemp"
#define ZZDownloadTaskManagerTaskFileDir @"zzdownloadtaskmanagertaskfile"

static int AFDownloadRequestOperationKeyRT;

@interface ZZDownloadTaskManager ()

@property (nonatomic, strong) NSMutableDictionary *allTaskDict;
@property (nonatomic, strong) NSMutableArray *allDownloadRequests;
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
                [self executeDownloadQueue];
            }
            continue;
        } else {
            NSString *targetPath = [destinationPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.section",i]];
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[entity getSectionUrlWithCount:i]]];
            AFDownloadRequestOperation *rq = [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:targetPath shouldResume:YES];
            objc_setAssociatedObject(rq, &AFDownloadRequestOperationKeyRT, entity.entityKey, OBJC_ASSOCIATION_RETAIN);
            
            [rq setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile){
                if (existedTask.command == ZZDownloadAssignedCommandStart) {
                    if (bytesRead > 0) {
                        existedTask.state = ZZDownloadStateDownloading;
                        existedTask.command = ZZDownloadAssignedCommandNone;
                    }
                }
                static BOOL x = NO;
                if (!x) {
//                    [[ZZDownloadManager shared] pauseEpTaskWithEpId:@"123"];
                    [operation pause];
                    x = YES;
                }
//                NSLog(@"i am %@-%d,my progress = %f", @"", i,totalBytesReadForFile*1.0 / totalBytesExpectedToReadForFile);
            }];
            
            [rq setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                if (operation.response.statusCode >= 200 && operation.response.statusCode < 400) {
                    NSLog(@"i downloaded %@-%d", existedTask.key, i);
                    [self startTask:existedTask];
                } else if (operation.response.statusCode >= 400) {
                    [[NSFileManager defaultManager] removeItemAtPath:targetPath error:NULL];
                    existedTask.triedCount += 1;
                    if (existedTask.triedCount > 5) {
                        existedTask.state = ZZDownloadStateInvalid;
                        [self writeTaskToDisk:existedTask];
                    }
                    [self startTask:existedTask];
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error){
                NSLog(@"sth download error happened=%@",error);
            }];
            [self.allDownloadRequests insertObject:rq atIndex:0];
            [self executeDownloadQueue];
            break;
        }
    }
}

- (void)executeDownloadQueue
{
    if ([[ZZDownloadUrlConnectionQueue shared] operationCount] == 0 && self.allDownloadRequests.count > 0) {
        [[ZZDownloadUrlConnectionQueue shared] addOperation:self.allDownloadRequests[0]];
        [self.allDownloadRequests removeObjectAtIndex:0];
    }
}

- (void)startTask:(ZZDownloadTask *)task
{
    if (!task || task.command != ZZDownloadAssignedCommandStart || task.state == ZZDownloadStateInvalid) {
        return;
    }
    [self notifyQueueUpdateMessage:task];
    NSLog(@"i assign %@", task.key);
    ZZDownloadBaseEntity *entity = [task recoverEntity];
    [self assignDownloadSectionTask:entity];
    [self writeTaskToDisk:task];
}

- (void)pauseTask:(ZZDownloadTask *)task
{
    if (!task || task.command != ZZDownloadAssignedCommandPause || task.state == ZZDownloadStateInvalid) {
        return;
    }
    [self notifyQueueUpdateMessage:task];
    BOOL downloading = NO;
    NSLog(@"i stop %@", task.key);
    AFDownloadRequestOperation *op = self.allDownloadRequests[0];
    if (op) {
        NSString *key = objc_getAssociatedObject(op, &AFDownloadRequestOperationKeyRT);
        if (key) {
            ZZDownloadTask *task = self.allTaskDict[key];
            if (task) {
                if ([task.key isEqualToString:key]) {
                    downloading = YES;
                    [op pause];
                    task.state = ZZDownloadStatePaused;
                    task.command = ZZDownloadAssignedCommandNone;
                }
            }
        }
    }
    if (!downloading) {
        task.state = ZZDownloadCommandStop;
    }
    [self writeTaskToDisk:task];
}

- (void)removeTask:(ZZDownloadTask *)task
{
    if (!task) {
        return;
    }
    [self notifyQueueUpdateMessage:task];
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
