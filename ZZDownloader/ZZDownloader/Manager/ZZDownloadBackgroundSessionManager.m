//
//  ZZDownloadBackgroundSessionManager.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 12/18/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloadBackgroundSessionManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "ZZDownloadTaskManagerV2.h"
#import "ZZDownloadTaskCFNetworkOperation.h"

#define ZZDownloadBackgroundSessionManagerName "ZZDownloadUrlSessionOpThread"

@interface ZZDownloadBackgroundSessionManager ()
@property (nonatomic, strong) NSMutableArray *allTaskList;
@property (nonatomic) NSMutableDictionary *deathNote;
@property (nonatomic) dispatch_queue_t bgSessionQueue;
@property (nonatomic,weak) ZZDownloadTaskManagerV2<ZZDownloadTaskOperationDelegate> *delegate;
@end

@interface ZZDownloadBackgroundTaskRecord : NSObject
@property (nonatomic) long long downloadedCount;
@property (nonatomic) int32_t lazyCount;
@end

@implementation ZZDownloadBackgroundTaskRecord

@end

@implementation ZZDownloadBackgroundSessionManager
+ (id)shared
{
    static dispatch_once_t onceToken;
    static ZZDownloadBackgroundSessionManager *manager;
    dispatch_once(&onceToken, ^{
        if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
            manager = nil;
            return ;
        }
        
        NSURLSessionConfiguration *config;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.zzdownloder.session.manager.background.identifier.v3"];
        } else {
            config = [NSURLSessionConfiguration backgroundSessionConfiguration:@"com.zzdownloder.session.manager.background.identifier.v3"];
        }
        config.allowsCellularAccess = NO;
        
        manager = [[ZZDownloadBackgroundSessionManager alloc] initWithSessionConfiguration:config];
        manager.delegate = [ZZDownloadTaskManagerV2 shared];
        manager.bgSessionQueue = dispatch_queue_create("com.zzdownloder.zzdownloadbackgroundsessionmanager.queue", DISPATCH_QUEUE_SERIAL);
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        dispatch_async(manager.bgSessionQueue, ^{
            manager.allTaskList = [NSMutableArray array];
            manager.deathNote = [NSMutableDictionary dictionary];
            [manager initSessionManager];
            
            NSArray *arr = manager.downloadTasks;
            for (NSURLSessionTask *task in arr) {
                if (task.taskDescription) {
                    [manager.allTaskList addObject:task.taskDescription];
                }
            }
            dispatch_semaphore_signal(semaphore);
        });
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        
    });
    return manager;
}

- (void)checkSelf
{
    dispatch_async(self.bgSessionQueue, ^{
        NSArray *downloadTask = self.downloadTasks;
        for (NSURLSessionTask *task in downloadTask) {
            if (task.state == NSURLSessionTaskStateRunning) {
                ZZDownloadBackgroundTaskRecord *record = self.deathNote[task.taskDescription];
                if (!record) {
                    record = [ZZDownloadBackgroundTaskRecord new];
                    record.lazyCount = -1;
                    record.downloadedCount = task.countOfBytesReceived;
                }
                if (task.countOfBytesReceived == record.downloadedCount && task.countOfBytesReceived != task.countOfBytesExpectedToReceive) {
                    record.lazyCount += 1;
                }
                if (record.lazyCount > 3) {
                    [task cancel];
                    [self.allTaskList removeObject:task.taskDescription];
                }
            }
        }
    });
    
}

- (void)addCacheTaskByTasks:(NSArray *)outtasks completionBlock:(void (^)(NSNumber *))block
{
    __block NSArray *tasks = outtasks;
    dispatch_async(self.bgSessionQueue, ^{
        if (self.downloadTasks.count > 5) {
            if (block) block(@(0));
            return ;
        }
        __block int32_t added = 0;
        
        for (ZZDownloadTask *task in tasks) {
            __block ZZDownloadBaseEntity *entity = [task recoverEntity];
            if ([entity updateSelf]) {
                [self.delegate updateTaskWithBlock:^{
                    task.sectionsDownloadedList = [NSMutableArray array];
                    task.sectionsLengthList = [NSMutableArray array];
                    task.sectionsContentTime = [NSMutableArray array];
                    int sections = entity.sections;
                    for (int i = 0; i < sections; i++) {
                        [task.sectionsDownloadedList addObject:[NSNumber numberWithLongLong:0]];
                        [task.sectionsLengthList addObject:[NSNumber numberWithLongLong:0]];
                        [task.sectionsContentTime addObject:[NSNumber numberWithUnsignedInteger:0]];
                    }
                    NSString *needTypeTag = [entity uniqueKey];
                    int32_t sectionCount = [entity getSectionCount];
                    
                    
                    for (int i = sectionCount - 1; i >= 0; i--) {
                        NSString *url = [entity getSectionUrlWithCount:i];
                        NSString *td = [self getTaskDescription:entity.entityKey section:i typeTag:needTypeTag];
                        NSString *tempPath = [ZZDownloadTaskCFNetworkOperation getBackgroundDownloadTempPath:entity.entityKey section:i typetag:needTypeTag];
                        task.sectionsContentTime[i] = [NSNumber numberWithLongLong:[entity getSectionTotalLengthWithCount:i]];
                        BOOL cacheExist = [[NSFileManager defaultManager] fileExistsAtPath:tempPath];
                        if ([self.allTaskList containsObject:td] || cacheExist) {
                            continue;
                        } else {
                            BOOL success = [self startUrlTask:url taskDescription:td];
                            added += success?1:0;
                        }
                    }
                    task.argv = [MTLJSONAdapter JSONDictionaryFromModel:entity];
                }];
                [self.delegate notifyUpdate:task.key];
                if (added > 2) {
                    break;
                }
                NSTimeInterval remain = [[UIApplication sharedApplication] backgroundTimeRemaining];
                if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground && remain < 5) {
                    break;
                }
            }
        }
        block(@(added));
    });
}

- (void)removeCacheTaskByTask:(ZZDownloadTask *)task section:(int32_t)section typeTag:(NSString *)typeTag
{
    dispatch_async(self.bgSessionQueue, ^{
        NSString *td = [self getTaskDescription:task.key section:section typeTag:typeTag];
        NSArray *downloadTask = self.downloadTasks;
        for (NSURLSessionTask *taskt in downloadTask) {
            if ([taskt.taskDescription isEqualToString:td]) {
                [taskt cancel];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.allTaskList removeObject:taskt.taskDescription];
                });
            }
        }
    });
}

- (NSString *)getTaskDescription:(NSString *)key section:(int32_t)section typeTag:(NSString *)typeTag
{
    return [NSString stringWithFormat:@"%@_|_%d_|_%@", key, section, typeTag];
}

- (void)getInfoFromDescription:(NSString *)taskDescription key:(NSString **)key section:(int32_t *)section typeTag:(NSString **)typeTag
{
    NSArray *arr = [taskDescription componentsSeparatedByString:@"_|_"];
    if (arr.count != 3) {
        return;
    }
    *key = arr[0];
    *section = [arr[1] intValue];
    *typeTag = arr[2];
}

- (BOOL)startUrlTask:(NSString *)url taskDescription:(NSString *)taskDescription
{
    if (!url) {
        return NO;
    }
    __block NSURLSessionDownloadTask *rq;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    rq = [self downloadTaskWithRequest:request progress:nil destination:nil completionHandler:nil];
    rq.taskDescription = taskDescription;
    [self.allTaskList addObject:rq.taskDescription];
    [rq resume];
    
    return rq != nil;
}

- (void)initSessionManager
{
    __weak __typeof(self) weakSelf = self;
    [self setDidFinishEventsForBackgroundURLSessionBlock:^(NSURLSession *session){
        NSLog(@"background awake");
    }];
    
    [self setSessionDidBecomeInvalidBlock:^(NSURLSession *session, NSError *error) {
    }];
    
    [self setTaskDidCompleteBlock:^(NSURLSession *session, NSURLSessionTask *task, NSError *error) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        
        NSData *resumeDate = error.userInfo[@"NSURLSessionDownloadTaskResumeData"];
        if (resumeDate) {
            NSError *error2;
            NSDictionary *resumeDictionary = [NSPropertyListSerialization propertyListWithData:resumeDate options:NSPropertyListImmutable format:NULL error:&error];
            if (resumeDictionary && error2) {
                NSString *localFilePath = [resumeDictionary objectForKey:@"NSURLSessionResumeInfoLocalPath"];
                [[NSFileManager new] removeItemAtPath:localFilePath error:nil];
            }
        }
        
        __block NSInteger remainCount;
        dispatch_async(strongSelf.bgSessionQueue, ^{
            remainCount = strongSelf.downloadTasks.count;
            if (remainCount <= 1 && [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
                NSString *key;
                int32_t section;
                NSString *typetag;
                
                [strongSelf getInfoFromDescription:task.taskDescription key:&key section:&section typeTag:&typetag];
                [[ZZDownloadTaskManagerV2 shared] checkSelfUnSecheduledWorkKey:key block:nil];
            } else {
            }
        });
        
    }];
    
    [self setDownloadTaskDidFinishDownloadingBlock:^(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        NSString *key;
        int32_t section;
        NSString *typetag;
        
        [strongSelf getInfoFromDescription:downloadTask.taskDescription key:&key section:&section typeTag:&typetag];
        NSString *tmpPath = [ZZDownloadTaskCFNetworkOperation getBackgroundDownloadTempPath:key section:section typetag:typetag];
        [[NSFileManager new] removeItemAtPath:tmpPath error:nil];
        return [NSURL fileURLWithPath:tmpPath];
    }];
}


@end
