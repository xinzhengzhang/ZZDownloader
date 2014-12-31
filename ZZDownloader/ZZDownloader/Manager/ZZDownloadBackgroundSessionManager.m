//
//  ZZDownloadBackgroundSessionManager.m
//  ibiliplayer
//
//  Created by zhangxinzheng on 12/18/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloadBackgroundSessionManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "ZZDownloadTaskManagerV2.h"
#import "ZZDownloadTaskCFNetworkOperation.h"

#define ZZDownloadBackgroundSessionManagerName "ZZDownloadUrlSessionOpThread"
//#define ZZDownloadBackgroundSessionAssert NSAssert([[NSThread currentThread].name isEqualToString:ZZDownloadBackgroundSessionManagerName], [NSString stringWithFormat:@"%s:%d",__FUNCTION__, __LINE__]);

@interface ZZDownloadBackgroundSessionManager ()
@property (nonatomic, strong) NSMutableArray *allTaskList;
@end

@implementation ZZDownloadBackgroundSessionManager
+ (id)shared
{
    static dispatch_once_t onceToken;
    static ZZDownloadBackgroundSessionManager *manager;
    dispatch_once(&onceToken, ^{
        if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
            manager = nil;
        }
        return ;
        NSURLSessionConfiguration *config;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.bilibi.session.manager.background.identifier.v3"];
        } else {
            config = [NSURLSessionConfiguration backgroundSessionConfiguration:@"com.bilibi.session.manager.background.identifier.v2"];
        }
        config.allowsCellularAccess = [[ZZDownloadTaskManagerV2 shared] enableDownloadUnderWWAN];
        
        
        manager = [[ZZDownloadBackgroundSessionManager alloc] initWithSessionConfiguration:config];
        
        manager.allTaskList = [NSMutableArray array];
        [manager initSessionManager];
        
        NSArray *arr = manager.downloadTasks;
        for (NSURLSessionTask *task in arr) {
            if (task.taskDescription) {
                [manager.allTaskList addObject:task.taskDescription];
            }
        }
    });
    return manager;
}


- (NSInteger)bgCachedCount
{
    return self.downloadTasks.count;
}

- (int32_t)addCacheTaskByTask:(ZZDownloadTask *)task
{
    ZZDownloadBaseEntity *entity = [task recoverEntity];
    if ([entity updateSelf]) {
        task.argv = [MTLJSONAdapter JSONDictionaryFromModel:entity];
    }
    
    NSString *needTypeTag = [entity uniqueKey];
    int32_t sectionCount = [entity getSectionCount];
    
    int32_t added = 0;
    
    for (int i = 0; i < sectionCount; i++) {
        NSString *url = [entity getSectionUrlWithCount:i];
        NSString *td = [self getTaskDescription:entity.entityKey section:i typeTag:needTypeTag];
        NSString *tempPath = [ZZDownloadTaskCFNetworkOperation getBackgroundDownloadTempPath:entity.entityKey section:i typetag:needTypeTag];
        BOOL cacheExist = [[NSFileManager defaultManager] fileExistsAtPath:tempPath];
        if ([self.allTaskList containsObject:td] || cacheExist) {
            continue;
        } else {
            BOOL success = [self startUrlTask:url taskDescription:td];
            added += success?1:0;
        }
    }
    return added;
}

- (void)removeCacheTaskByTask:(ZZDownloadTask *)task section:(int32_t)section typeTag:(NSString *)typeTag

{
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
    NSAssert(![NSThread isMainThread], @"ZZDownloadBackgroundSessionManager");
    __block NSURLSessionDownloadTask *rq;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        rq = [self downloadTaskWithRequest:request progress:nil destination:nil completionHandler:nil];
        rq.taskDescription = taskDescription;
        [self.allTaskList addObject:rq.taskDescription];
        [rq resume];
    });
    
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
        NSData *resumeDate = error.userInfo[@"NSURLSessionDownloadTaskResumeData"];
        if (resumeDate) {
            NSError *error2;
            NSDictionary *resumeDictionary = [NSPropertyListSerialization propertyListWithData:resumeDate options:NSPropertyListImmutable format:NULL error:&error];
            if (resumeDictionary && error2) {
                NSString *localFilePath = [resumeDictionary objectForKey:@"NSURLSessionResumeInfoLocalPath"];
                [[NSFileManager new] removeItemAtPath:localFilePath error:nil];
                
            }
        }
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
