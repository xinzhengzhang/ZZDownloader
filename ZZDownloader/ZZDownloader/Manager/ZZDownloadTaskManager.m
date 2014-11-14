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

#define ZZDownloadTaskManagerTaskDir @"zzdownloadtaskmanagertask"
#define ZZDownloadTaskManagerTaskTempDir @"zzdownloadtaskmanagertasktemp"
#define ZZDownloadTaskManagerTaskFileDir @"zzdownloadtaskmanagertaskfile"

@interface ZZDownloadTaskManager ()

@property (nonatomic, strong) NSMutableDictionary *allTaskDict;

@end

@implementation ZZDownloadTaskManager

+ (id)shared
{
    static ZZDownloadTaskManager *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadTaskManager alloc] init];
        queue.allTaskDict = [NSMutableDictionary dictionary];
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
        switch (operation.command) {
            case ZZDownloadCommandStart:
                [existedTask startWithStartSuccessBlock:^{
                    // notify pendstart
                    // assign task mession
                }];
                break;
            case ZZDownloadCommandStop:
                [existedTask pauseWithPauseSuccessBlock:^{
                    // notify pend pause
                    // pause task in queue
                }];
                break;
            case ZZDownloadCommandRemove:
                [existedTask removeWithRemoveSuccessBlock:^{
                    // notify pend remove
                    // pause task in queue
                }];
                break;
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
        NSString *cacheDir = NSTemporaryDirectory();
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
        NSString *cacheDir = NSTemporaryDirectory();
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
        NSString *cacheDir = NSTemporaryDirectory();
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
