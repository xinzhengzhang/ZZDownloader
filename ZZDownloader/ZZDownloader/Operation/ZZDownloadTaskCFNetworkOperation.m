//
//  ZZDownloadTaskCFNetworkOperation.m
//  Pods
//
//  Created by zhangxinzheng on 12/12/14.
//
//

#import "ZZDownloadTaskCFNetworkOperation.h"
#import "ZZDownloadBaseEntity.h"
#import "ZZDownloadTask+Helper.h"
#import <CommonCrypto/CommonDigest.h>
//#import "libavformat/version.h"
#import "ZZDownloadTaskManagerV2.h"
#import <sys/time.h>
#import "ZZDownloadBackgroundSessionManager.h"

//#define ZZDownloadTaskManagerTaskDir @".Downloads/zzdownloadtaskmanagertask"
//#define ZZDownloadTaskManagerTaskFileDir @".Downloads/zzdownloadtaskmanagertaskfile"
//#define ZZDownloadTaskManagerTaskFileDirTmp @".Downloads/zzdownloadtaskmanagertaskfiletmp"




@interface ZZDownloadTaskCFNetworkOperation () {
    struct timeval container;
}
@property (nonatomic) NSFileManager *fileManager;
@property (nonatomic) ZZDownloadTask *downloadTask;
@property (nonatomic) ZZTaskOperationState state;
@property (nonatomic) NSRecursiveLock *lock;
@property (nonatomic) uint64_t clock;
@property (nonatomic) int32_t continuousFailCount;
@property (nonatomic) int8_t redirectCount;

- (void)finish;
@end

@implementation ZZDownloadTaskCFNetworkOperation

- (id)initWithTask:(ZZDownloadTask *)task
{
    if (self = [super init]) {
        self.downloadTask = task;
        self.fileManager = [NSFileManager new];
        self.state = ZZTaskOperationStateReady;
        self.clock = clock();
        self.continuousFailCount = 0;
        self.redirectCount = 0;
    }
    return self;
}

- (NSString *)key
{
    return self.downloadTask.key;
}

#pragma mark - private
- (void)finish
{
    self.state = ZZTaskOperationStateFinish;
}

#pragma mark -
- (void)setState:(ZZTaskOperationState)state
{
    if (!ZZStateTransitionIsValid(self.state, state, [self isCancelled])) {
        return;
    }
    
    NSString *oldStateKey = ZZKeyPathFromOperationState(self.state);
    NSString *newStateKey = ZZKeyPathFromOperationState(state);
    
    [self willChangeValueForKey:newStateKey];
    [self willChangeValueForKey:oldStateKey];
    _state = state;
    [self didChangeValueForKey:oldStateKey];
    [self didChangeValueForKey:newStateKey];
    [self notify:YES];
}

- (BOOL)isReady
{
    return self.state == ZZTaskOperationStateReady && [super isReady];
}

- (BOOL)isExecuting
{
    return self.state == ZZTaskOperationStateExecuting;
}

- (BOOL)isFinished
{
    return self.state == ZZTaskOperationStateFinish;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (void)start
{
    if (self.downloadTask.command == ZZDownloadAssignedCommandStart) {
        self.downloadTask.command = ZZDownloadAssignedCommandNone;
    }
    if (self.isCancelled) {
        [self finish];
    } else if (self.isReady) {
        [self parse];
    }
}

- (void)pause
{
    [self cancel];
}

- (void)remove
{
    [self cancel];
}

- (void)cancel
{
    [self finish];
    [super cancel];
}

- (NSString *)bgCachedPath:(int32_t)section typeTag:(NSString *)typeTag
{
    NSString *targetPath = [self.class getBackgroundDownloadTempPath:self.downloadTask.key section:section typetag:typeTag];
    if ([self videoFileValid:targetPath]) {
        return targetPath;
    }
    return nil;
}

- (void)parse
{
    if (!self.downloadTask) {
        [self finish];
        return;
    }
   
    self.state = ZZTaskOperationStateExecuting;
    
    ZZDownloadBaseEntity *entity = [self.downloadTask recoverEntity];
    ZZDownloadState ts = self.downloadTask.state;
    self.downloadTask.state = ZZDownloadStateParsing;

    NSString *needTypeTag = [entity getTypeTag:YES];
    int32_t sectionCount = [entity getSectionCount];
    
    BOOL parseSeccuess = sectionCount != 0;
    if (parseSeccuess) {
        BOOL x1 = self.downloadTask.sectionsLengthList.count == sectionCount;
        BOOL x2 = self.downloadTask.sectionsDownloadedList.count == sectionCount;
        BOOL x3 = (self.downloadTask.argv[@"typeTag"] != NSNull.null) && [self.downloadTask.argv[@"typeTag"] isEqualToString:needTypeTag];
        [self.delegate updateTaskWithBlock:^{
            if (!x1 || !x2 || !x3) {
                [self overdueTask];
                for (int i = 0; i < sectionCount; i++) {
                    [self.downloadTask.sectionsDownloadedList addObject:[NSNumber numberWithLongLong:0]];
                    [self.downloadTask.sectionsLengthList addObject:[NSNumber numberWithLongLong:0]];
                    [self.downloadTask.sectionsContentTime addObject:[NSNumber numberWithUnsignedInteger:0]];
                }
            }
            self.downloadTask.argv = [MTLJSONAdapter JSONDictionaryFromModel:entity];
        }];
        [entity downloadDanmakuWithDownloadStartBlock:^{
            self.downloadTask.state = ZZDownloadStateDownloadingDanmaku;
        }];
        [entity downloadCoverWithDownloadStartBlock:^{
            self.downloadTask.state = ZZDownloadStateDownloadingCover;
        }];
        
        NSString *destinationPath = [[self downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
        NSArray *existedFile = [self getBiliTaskFileNameList:destinationPath suffix:@"section"];
        
        self.downloadTask.state = ts;
        
        for (int i = 0; i < sectionCount; i++) {
            if ([existedFile containsObject:[NSString stringWithFormat:@"%d.section", i]]) {
                if (i == (sectionCount -1)) {
                    self.downloadTask.state = ZZDownloadStateDownloaded;
                    self.downloadTask.lastestError = nil;
                    self.downloadTask.command = ZZDownloadAssignedCommandNone;
                    [self.delegate notifyUpdate:self.downloadTask.key];
                }
                continue;
            } else {
                NSUInteger totalLength = [entity getSectionTotalLengthWithCount:i];
                self.downloadTask.sectionsContentTime[i] = [NSNumber numberWithUnsignedInteger:totalLength];
                BOOL success = NO;
                NSString *tempBgCache = [self bgCachedPath:i typeTag:needTypeTag];
                if (tempBgCache) {
                    success = [self transferSection:i tempPath:tempBgCache];
                }
                if (!success) {
                    self.downloadTask.state = ZZDownloadStateWaiting;
                    success = [self downloadSection:i];
                    tempBgCache = [self bgCachedPath:i typeTag:needTypeTag];
                    if (tempBgCache) {
                        [self.fileManager removeItemAtPath:tempBgCache error:nil];
                    } else if (success){
                        [[ZZDownloadBackgroundSessionManager shared] removeCacheTaskByTask:self.downloadTask section:i typeTag:needTypeTag];
                    }
                }
                if (success) {
                    if (i == (sectionCount -1) && success) {
                        self.downloadTask.state = ZZDownloadStateDownloaded;
                        self.downloadTask.lastestError = nil;
                        self.downloadTask.command = ZZDownloadAssignedCommandNone;
                        [self.delegate notifyUpdate:self.downloadTask.key];
                    }
                } else if (self.downloadTask.state == ZZDownloadStateDownloading && self.state != ZZTaskOperationStateFinish){
                    self.continuousFailCount += 1;
                    self.downloadTask.state = ZZDownloadStateFail;
                    if (self.continuousFailCount > 5) {
                        [self finish];
                        return;
                    } else{
                        sleep(2);
                        [self parse];
                        return;
                    }
                } else {
                    break;
                }
            }
        }
    } else {
        self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"task parse fail:%@command:%d state:%d", self.downloadTask.key, (int32_t)self.downloadTask.command, (int32_t)self.downloadTask.state]}];
    }
    
    [self finish];
}

- (void)overdueTask
{
    self.downloadTask.state = ZZDownloadStateWaiting;
    self.downloadTask.triedCount = 0;
    self.downloadTask.sectionsDownloadedList = [NSMutableArray array];
    self.downloadTask.sectionsLengthList = [NSMutableArray array];
    self.downloadTask.sectionsContentTime = [NSMutableArray array];
    
    ZZDownloadBaseEntity *entity = [self.downloadTask recoverEntity];
    NSString *destinationPath = [[self downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
    NSError *error;
    [self.fileManager removeItemAtPath:destinationPath error:&error];
    if (error) {
        self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"task:%@ remove fail when over due", self.downloadTask.key], @"originError": error}];
    }
}

- (NSString *)tempPath:(NSString *)targetPath {
    NSString *tempPath = nil;
    if (targetPath) {
        NSString *rootPath = NSHomeDirectory();
        NSString *subPath = [targetPath substringFromIndex:[rootPath length]];
        NSString *md5URLString = [self.class md5StringForString:subPath];
        tempPath = [[self cacheFolder] stringByAppendingPathComponent:md5URLString];
    }
    return tempPath;
}

- (BOOL)downloadUrl:(NSString *)targetPath destionPath:(NSString *)destinationPath tmpPath:(NSString *)tmpPath index:(int32_t)index
{
    BOOL downloadSuccess = NO;

    boolean_t fdsuccess = true;
   
    NSURL *url = [NSURL fileURLWithPath:tmpPath];
    
    CFURLRef locationPathRef = (__bridge CFURLRef)url;
    
    CFWriteStreamRef writeRef = CFWriteStreamCreateWithFile(NULL, locationPathRef);
    
    boolean_t fileExisted = false;
    if (writeRef) {
        if ([self.fileManager fileExistsAtPath:tmpPath]) {
            fileExisted = true;
        }
    } else {
        fdsuccess = false;
    }
    
    CFHTTPMessageRef messageRef = CFHTTPMessageCreateRequest(NULL, CFStringCreateWithCString(NULL, "GET", kCFStringEncodingUTF8), CFURLCreateWithString(NULL, CFSTR(""), CFURLCreateWithString(NULL, (__bridge CFStringRef)targetPath, NULL)), kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Content-Type"), CFSTR("charset=utf-8"));
//    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("User-Agent"), CFSTR(LIBAVFORMAT_IDENT));
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Accept"), CFSTR("*/*"));
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Accept-Encoding"), CFSTR("gzip,deflate,sdch"));
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Accept-Language"), CFSTR("zh-CN,zh;q=0.8"));
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Connection"), CFSTR("close,TE"));
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("te"), CFSTR("trailers"));
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("HOST"), (__bridge CFStringRef)[[NSURL URLWithString:targetPath] host]);
    
    
    boolean_t focusRange = ![self.downloadTask.argv[@"from"] isEqual:NSNull.null] && [self.downloadTask.argv[@"from"] isEqualToString:@"pptv"];
    boolean_t setRange = false;
    if (fileExisted) {
        unsigned long long downloadedBytes = [self fileSizeForPath:tmpPath];
        if (downloadedBytes > 1) {
            downloadedBytes--;
            CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Range"), (__bridge CFStringRef)[NSString stringWithFormat:@"bytes=%llu-", downloadedBytes]);
            setRange = true;
        }
    }
    if (focusRange && !setRange) {
        CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Range"), CFSTR("bytes=0-"));
    }
    
    CFReadStreamRef requestStream = CFReadStreamCreateForHTTPRequest(NULL, messageRef);
    boolean_t openStatus = CFReadStreamOpen(requestStream);
    if (!openStatus) {
        fdsuccess = false;
        [self finish];
    }
    
    
    if (fdsuccess) {
        uint8_t buf[4096];
        CFIndex bytesRead = 0, bytesWrite = 0;
        
        memset(buf, 0, sizeof(buf));
        bytesRead = CFReadStreamRead(requestStream, buf, sizeof(buf));
        CFHTTPMessageRef myResponse = (CFHTTPMessageRef)CFReadStreamCopyProperty(requestStream, kCFStreamPropertyHTTPResponseHeader);
        CFIndex errorCode = CFHTTPMessageGetResponseStatusCode(myResponse);
        
        if (bytesRead < 0 || errorCode >= 400) {
            self.redirectCount = 0;
            self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{@"":[NSString stringWithFormat:@"task=%@ url=%@ errcode=%ld",self.downloadTask.key,targetPath,errorCode]
                                                                                                                                               }];
        } else if (errorCode >= 300 && errorCode < 400) {
            CFDictionaryRef allHeader = CFHTTPMessageCopyAllHeaderFields(myResponse);
            NSString *redirectUrl = CFDictionaryGetValue(allHeader, @"Location");
            if (redirectUrl) {
                self.redirectCount += 1;
                if (self.redirectCount < 6) {
                    downloadSuccess = [self downloadUrl:redirectUrl destionPath:destinationPath tmpPath:tmpPath index:index];
                }
            }
            CFRelease(allHeader);
        } else if (errorCode >= 200 && errorCode < 300){
            self.redirectCount = 0;
            long long totalContentLength = 0;
            long long totalDownloaded = bytesRead;
            long long fileOffset = -1;
            CFDictionaryRef allHeader = CFHTTPMessageCopyAllHeaderFields(myResponse);
            CFStringRef rcontentLength = CFDictionaryGetValue(allHeader, @"Content-Length");
            totalContentLength = [(__bridge NSString *)rcontentLength longLongValue];
            if (errorCode == 206) {
                CFStringRef rcontentRange = CFDictionaryGetValue(allHeader, @"Content-Range");
                NSString *contentRange = (__bridge NSString *)rcontentRange;
                if ([contentRange hasPrefix:@"bytes"]) {
                    NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
                    if ([bytes count] == 4) {
                        fileOffset = [bytes[1] longLongValue];
                        totalContentLength = [bytes[3] longLongValue];
                    }
                }
                if (fileOffset != -1) {
                    long long downloadedBytes = [self fileSizeForPath:tmpPath];
                    if (fileOffset != downloadedBytes) {
                        CFWriteStreamClose(writeRef);
                        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:tmpPath];
                        [file truncateFileAtOffset:fileOffset];
                        [file closeFile];
                        writeRef = CFWriteStreamCreateWithFile(NULL, locationPathRef);
                        CFWriteStreamSetProperty(writeRef, kCFStreamPropertyAppendToFile, kCFBooleanTrue);
                        totalDownloaded += fileOffset;
                    }
                    //                    CFWriteStreamSetProperty(writeRef, kCFStreamPropertyFileCurrentOffset, (__bridge CFNumberRef)[NSNumber numberWithLongLong:fileOffset]);
                    //                    CFWriteStreamSetProperty(writeRef, kCFStreamPropertyAppendToFile, kCFBooleanTrue);
                }
            }
            self.downloadTask.sectionsLengthList[index] = [NSNumber numberWithLongLong:totalContentLength];
            BOOL couldDownload = [self hasFreeSpaceForDownloading:totalContentLength];
            if (couldDownload) {
                openStatus = CFWriteStreamOpen(writeRef);
            } else {
                openStatus = false;
                self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey: @"磁盘已满"}];
            }
            if (!openStatus) {
                fdsuccess = false;
                [self finish];
            } else {
                self.downloadTask.state = ZZDownloadStateDownloading;
                bytesWrite = CFWriteStreamWrite(writeRef, buf, bytesRead);
                boolean_t errorHappen = false;
                while (bytesRead > 0){
                    @autoreleasepool {
                        if ([self notify:NO]) {
                            self.downloadTask.sectionsDownloadedList[index] = [NSNumber numberWithLongLong:totalDownloaded];
                        }
                        memset(buf, 0, sizeof(buf));
                        if (self.downloadTask.command == ZZDownloadAssignedCommandPause || self.downloadTask.command == ZZDownloadAssignedCommandRemove || self.downloadTask.command == ZZDownloadAssignedCommandInterruptPaused) {
                            // canceled
                            errorHappen = true;
                            if (self.downloadTask.command == ZZDownloadAssignedCommandPause) {
                                self.downloadTask.state = ZZDownloadStateRealPaused;
                            } else if (self.downloadTask.command == ZZDownloadAssignedCommandInterruptPaused) {
                                self.downloadTask.state = ZZDownloadStateInterrputPaused;
                            } else if (self.downloadTask.command == ZZDownloadAssignedCommandRemove) {
                                self.downloadTask.state = ZZDownloadStateInterrputPaused;
                            }
                            [self finish];
                            break;
                        }
                        bytesRead = CFReadStreamRead(requestStream, buf, sizeof(buf));
                        if (self.state == ZZTaskOperationStateFinish) {
                            errorHappen = true;
                            break;
                        } else if (bytesRead > 0) {
                            bytesWrite = CFWriteStreamWrite(writeRef, buf, bytesRead);
                            totalDownloaded += bytesWrite;
                            if (bytesWrite <= 0) {
                                errorHappen = true;
                                CFStreamError error = CFWriteStreamGetError(writeRef);
                                self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{@"cferrorCode":[NSString stringWithFormat:@"%d",error.error],
                                                                                                                                                                   @"cferroDomin":[NSString stringWithFormat:@"%ld",error.domain]}];
                                break;
                            }
                        } else {
                            
                            if (CFReadStreamGetStatus(requestStream) == kCFStreamStatusError) {
                                errorHappen = true;
                                CFStreamError error = CFReadStreamGetError(requestStream);
                                self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{@"cferrorCode":[NSString stringWithFormat:@"%d",error.error],
                                                                                                                                                                   @"cferroDomin":[NSString stringWithFormat:@"%ld",error.domain]}];
                                break;
                            }
                        }
                    }
                };
                if (requestStream) {
                    CFReadStreamClose(requestStream);
                }
                if (writeRef) {
                    CFWriteStreamClose(writeRef);
                }
                if (!errorHappen && [self videoFileValid:tmpPath]) {
                    NSError *fileE = nil;
                    [self.fileManager removeItemAtPath:destinationPath error:nil];
                    [self.fileManager moveItemAtPath:tmpPath toPath:destinationPath error:&fileE];
                    if (fileE) {
                        self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{@"originError":fileE}];
                    } else {
                        downloadSuccess = YES;
                    }
                }
            }
        }
        if (myResponse) {
            CFRelease(myResponse);
        }
    }
    
    CFRelease(requestStream);
    CFRelease(writeRef);
    CFRelease(messageRef);
    return downloadSuccess;
}

- (BOOL)hasFreeSpaceForDownloading:(long long)totalBytes
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask , YES) objectAtIndex:0];
    NSFileManager *fileManager = self.fileManager;
    NSDictionary *fileSysAttributes = [fileManager attributesOfFileSystemForPath:path error:nil];
    NSNumber *freeSpace = [fileSysAttributes objectForKey:NSFileSystemFreeSize];
    if ([freeSpace longLongValue] - totalBytes > 200 * 1024 * 1024) {
        return YES;
    }
    return NO;
}

- (BOOL)transferSection:(int32_t)index tempPath:(NSString *)tempPath
{
    ZZDownloadBaseEntity *entity = [self.downloadTask recoverEntity];
    NSString *destinationPath = [[[self downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]] stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.section", index]];
    NSError *fileE;
    [self.fileManager removeItemAtPath:destinationPath error:nil];
    [self.fileManager moveItemAtPath:tempPath toPath:destinationPath error:&fileE];
    if (fileE) {
        self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{@"originError":fileE}];
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)downloadSection:(int32_t)index
{
    ZZDownloadBaseEntity *entity = [self.downloadTask recoverEntity];
    NSString *destinationPath = [[[self downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]] stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.section", index]];
    NSString *tmpPath = [self tempPath:destinationPath];
    NSString *targetPath = [entity getSectionUrlWithCount:index];
    [self notify:YES];
    return [self downloadUrl:targetPath destionPath:destinationPath tmpPath:tmpPath index:index];
}

- (BOOL)notify:(BOOL)focus
{
    gettimeofday(&container, NULL);
    uint64_t now = ((uint64_t)container.tv_sec) * 1000 + container.tv_usec/1000;
    if (now < self.clock || (now - self.clock) > 500 || focus) {
        [self.delegate notifyUpdate:self.downloadTask.key];
        self.clock = now;
        return YES;
    }
    return NO;
}


#pragma mark - tool
- (BOOL)videoFileValid:(NSString *)filePath
{
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    long long x = [dict[NSFileSize] longLongValue];
    if (x > 100 * 1024) {
        return YES;
    }
    return NO;
}

- (NSString *)downloadFolder {
    NSFileManager *filemgr = self.fileManager;
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

- (NSArray *)getBiliTaskFileNameList:(NSString *)dirPath suffix:(NSString *)suffix
{
    NSString *taskPath = dirPath;
    NSMutableArray *nameList = [NSMutableArray array];
    if(![self.fileManager createDirectoryAtPath:taskPath withIntermediateDirectories:YES attributes:nil error:nil]) {
        NSLog(@"Failed to create section directory at %@", taskPath);
    }
    NSArray *tmpList = [self.fileManager contentsOfDirectoryAtPath:taskPath error:nil];
    for (NSString *fileName in tmpList) {
        NSString *fullPath = [taskPath stringByAppendingPathComponent:fileName];
        BOOL x = NO;
        if ([self.fileManager fileExistsAtPath:fullPath isDirectory:&x]) {
            if ([[fileName pathExtension] isEqualToString:suffix]) {
                [nameList addObject:fileName];
            }
        }
    }
    return nameList;
}

+ (NSString *)getBackgroundDownloadTempPath:(NSString *)key section:(int32_t)section typetag:(NSString *)typeTag
{
    NSString *tempPath = NSTemporaryDirectory();
    NSString *md5URLString = [self md5StringForString:[NSString stringWithFormat:@"%@_ni_lai_po_jie_%dwo_a_ni_%@yao_wo_a_bgfile", key, section, typeTag]];
    tempPath = [tempPath stringByAppendingPathComponent:[NSString stringWithFormat:@"bilibili_%@",md5URLString]];
    return tempPath;
}

- (NSString *)taskFolder {
    NSFileManager *filemgr = self.fileManager;
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

- (NSString *)cacheFolder {
    NSFileManager *filemgr = self.fileManager;
    static NSString *cacheFolder;
    
    if (!cacheFolder) {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:ZZDownloadTaskManagerTaskFileDirTmp];
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

- (unsigned long long)fileSizeForPath:(NSString *)path {
    signed long long fileSize = 0;
    NSFileManager *fileManager = self.fileManager;
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [fileManager attributesOfItemAtPath:path error:&error];
        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    return fileSize;
}

@end

