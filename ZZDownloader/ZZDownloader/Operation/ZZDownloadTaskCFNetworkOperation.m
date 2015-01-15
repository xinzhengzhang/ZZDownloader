//
//  ZZDownloadTaskCFNetworkOperation.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 12/12/14.
//
//

#import "ZZDownloadTaskCFNetworkOperation.h"
#import "ZZDownloadBaseEntity.h"
#import "ZZDownloadTask+Helper.h"
#import <CommonCrypto/CommonDigest.h>
#import "ZZDownloadTaskManagerV2.h"
#import <sys/time.h>
#import "ZZDownloadBackgroundSessionManager.h"


@interface ZZDownloadTaskCFNetworkOperation () {
    struct timeval container;
}
@property (nonatomic) NSFileManager *fileManager;
@property (nonatomic) ZZDownloadTask *downloadTask;
@property (nonatomic, readwrite) ZZTaskOperationState state;
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
    } else if (self.isReady && [self hasFreeSpaceForDownloading:0]) {
        self.state = ZZTaskOperationStateExecuting;
        [self parse];
    } else {
        self.state = ZZTaskOperationStateExecuting;
        sleep(1);
        [self finish];
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
    int32_t minkb = 100;
    if (section != 0) {
        minkb = 10;
    }
    if ([self videoFileValid:targetPath minKb:minkb]) {
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
    
    ZZDownloadBaseEntity *entity = [self.downloadTask recoverEntity];
    ZZDownloadState ts = self.downloadTask.state;
    self.downloadTask.state = ZZDownloadStateParsing;
    
    BOOL parseSeccuess = [entity updateSelf];
    if (parseSeccuess && self.state != ZZTaskOperationStateFinish) {
        int32_t sectionCount = [entity getSectionCount];
        [self.delegate updateTaskWithBlock:^{
            if (![entity isValid:self.downloadTask]) {
                [self overdueTask:entity];
                for (int i = 0; i < sectionCount; i++) {
                    [self.downloadTask.sectionsDownloadedList addObject:[NSNumber numberWithLongLong:0]];
                    [self.downloadTask.sectionsLengthList addObject:[NSNumber numberWithLongLong:0]];
                    [self.downloadTask.sectionsContentTime addObject:[NSNumber numberWithUnsignedInteger:0]];
                }
            }
            self.downloadTask.argv = [MTLJSONAdapter JSONDictionaryFromModel:entity];
        }];
        [self.delegate notifyUpdate:entity.entityKey];
        [entity downloadDanmakuWithDownloadStartBlock:^{
            self.downloadTask.state = ZZDownloadStateDownloadingDanmaku;
        }];
        [entity downloadCoverWithDownloadStartBlock:^{
            self.downloadTask.state = ZZDownloadStateDownloadingCover;
        }];
        
        self.downloadTask.state = ts;
        
        NSString *destinationPath = [[self downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
        NSArray *existedFile = [self getTaskFileNameList:destinationPath suffix:@"section"];
        
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
                NSString *tempBgCache = [self bgCachedPath:i typeTag:entity.uniqueKey];
                if (tempBgCache) {
                    success = [self transferSection:i tempPath:tempBgCache];
                }
                if (!success) {
                    self.downloadTask.state = ZZDownloadStateWaiting;
                    success = [self downloadSection:i];
                    tempBgCache = [self bgCachedPath:i typeTag:entity.uniqueKey];
                    if (tempBgCache) {
                        [self.fileManager removeItemAtPath:tempBgCache error:nil];
                    } else if (success){
                        [[ZZDownloadBackgroundSessionManager shared] removeCacheTaskByTask:self.downloadTask section:i typeTag:entity.uniqueKey];
                    }
                }
                if (success) {
                    if (i == (sectionCount -1) && success) {
                        self.downloadTask.state = ZZDownloadStateDownloaded;
                        self.downloadTask.lastestError = nil;
                        self.downloadTask.command = ZZDownloadAssignedCommandNone;
                        [self.delegate notifyUpdate:self.downloadTask.key];
                    }
                } else if ((self.downloadTask.state == ZZDownloadStateDownloading || self.downloadTask.state == ZZDownloadStateWaiting) && self.state != ZZTaskOperationStateFinish){
                    self.continuousFailCount += 1;
                    self.downloadTask.state = ZZDownloadStateFail;
                    if (self.continuousFailCount > 5) {
                        [self finish];
                        return;
                    } else if (![self hasFreeSpaceForDownloading:0]) {
                        [self finish];
                        return;
                    } else{
                        sleep(5);
                        [self parse];
                        return;
                    }
                } else {
                    break;
                }
            }
        }
    } else {
        if (self.state != ZZTaskOperationStateFinish) {
            self.downloadTask.state = ts;
            self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeInterruptError userInfo:@{NSLocalizedDescriptionKey:@"解析错误"}];
        } else {
            NSLog(@"blocking state and canceled");
        }
        
    }
    
    [self finish];
}

- (void)overdueTask:(ZZDownloadBaseEntity *)entity
{
    self.downloadTask.state = ZZDownloadStateWaiting;
    self.downloadTask.triedCount = 0;
    self.downloadTask.sectionsDownloadedList = [NSMutableArray array];
    self.downloadTask.sectionsLengthList = [NSMutableArray array];
    self.downloadTask.sectionsContentTime = [NSMutableArray array];
    
    NSString *destinationPath = [[self downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]];
    NSError *error;
    
    int32_t section = [entity getSectionCount];
    for (int i = 0; i < section; i++) {
        NSString *temp = [[[self downloadFolder] stringByAppendingPathComponent:[entity destinationDirPath]] stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.section", i]];
        temp = [self tempPath:temp];
        [self.fileManager removeItemAtPath:temp error:nil];
    }
    
    [self.fileManager removeItemAtPath:destinationPath error:&error];
    
    if (error) {
        //        self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey: @"文件删除错误"}];
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
    
    NSURL *urlx = [NSURL URLWithString:targetPath];
    CFHTTPMessageRef messageRef = CFHTTPMessageCreateRequest(NULL, CFSTR("GET"), (__bridge CFURLRef)urlx, kCFHTTPVersion1_1);
    
    NSError *jsonError;
    NSDictionary *dict = [MTLJSONAdapter JSONDictionaryFromModel:self.downloadTask];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&jsonError];
    NSString *argv = @"";
    if (!jsonError) {
        argv = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSDictionary *header = @{};
    NSMutableDictionary *defaultHeader = [NSMutableDictionary dictionaryWithObjects:@[@"charset=utf-8", @"Mozilla/5.0 (Linux; Android 4.1.1; Nexus 7 Build/JRO03D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Safari/535.19", @"*/*", @"identity;q=1, *;q=0", @"en-US,en;q=0.8,zh-CN;q=0.6,zh;q=0.4", @"keep-alive"] forKeys:@[@"Content-Type", @"User-Agent", @"Accept", @"Accept-Encoding", @"Accept-Language", @"Connection"]];
    if ([header isKindOfClass:[NSDictionary class]]) {
        [header enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            defaultHeader[key] = value;
        }];
    }
    
    [defaultHeader enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        CFHTTPMessageSetHeaderFieldValue(messageRef, (__bridge CFStringRef)key, (__bridge CFStringRef)value);
    }];
    //    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Content-Type"), CFSTR("charset=utf-8"));
    //    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("User-Agent"), CFSTR("Mozilla/5.0 (Linux; Android 4.1.1; Nexus 7 Build/JRO03D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Safari/535.19"));
    ////    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("User-Agent"), CFSTR(LIBAVFORMAT_IDENT));
    //    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Accept"), CFSTR("*/*"));
    //    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Accept-Encoding"), CFSTR("identity;q=1, *;q=0"));
    //    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Accept-Language"), CFSTR("en-US,en;q=0.8,zh-CN;q=0.6,zh;q=0.4"));
    //    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("Connection"), CFSTR("keep-alive"));
    CFHTTPMessageSetHeaderFieldValue(messageRef, CFSTR("HOST"), (__bridge CFStringRef)[urlx host]);
    
    
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
    
    CFReadStreamRef requestStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, messageRef);
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
        if (myResponse) {
            CFIndex errorCode = CFHTTPMessageGetResponseStatusCode(myResponse);
            
            CFDictionaryRef allHeader = CFHTTPMessageCopyAllHeaderFields(myResponse);
            if (bytesRead < 0 || errorCode >= 400) {
                self.redirectCount = 0;
                self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"http errcode=%ld",errorCode]
                                                                                                                                                   }];
            } else if (errorCode >= 300 && errorCode < 400) {
                NSString *redirectUrl = CFDictionaryGetValue(allHeader, @"Location");
                if (redirectUrl) {
                    self.redirectCount += 1;
                    if (self.redirectCount < 6) {
                        downloadSuccess = [self downloadUrl:redirectUrl destionPath:destinationPath tmpPath:tmpPath index:index];
                    } else {
                        self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey:@"重定向循环"}];
                    }
                }
            } else if (errorCode >= 200 && errorCode < 300){
                self.redirectCount = 0;
                long long totalContentLength = 0;
                long long totalDownloaded = 0;
                long long fileOffset = -1;
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
                            CFRelease(writeRef);
                            NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:tmpPath];
                            [file truncateFileAtOffset:fileOffset];
                            [file closeFile];
                            writeRef = CFWriteStreamCreateWithFile(NULL, locationPathRef);
                            CFWriteStreamSetProperty(writeRef, kCFStreamPropertyAppendToFile, kCFBooleanTrue);
                            totalDownloaded = fileOffset;
                        }
                    }
                }
                self.downloadTask.sectionsLengthList[index] = [NSNumber numberWithLongLong:totalContentLength];
                BOOL couldDownload = [self hasFreeSpaceForDownloading:totalContentLength];
                if (couldDownload) {
                    openStatus = CFWriteStreamOpen(writeRef);
                } else {
                    openStatus = false;
                }
                if (!openStatus) {
                    [self finish];
                } else {
                    self.downloadTask.state = ZZDownloadStateDownloading;
                    bytesWrite = CFWriteStreamWrite(writeRef, buf, bytesRead);
                    if (bytesWrite > 0) {
                        totalDownloaded += bytesWrite;
                    }
                    
                    boolean_t errorHappen = false;
                    int16_t writeCount = 0;
                    while (bytesRead > 0){
                        if (writeCount > 500) {
                            writeCount = 0;
                            if (![self hasFreeSpaceForDownloading:0]) {
                                errorHappen = true;
                                break;
                            }
                            self.downloadTask.state = ZZDownloadStateDownloading;
                        }
                        writeCount += 1;
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
                                    self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"文件写错误%d",(int)error.error]}];
                                    break;
                                }
                            } else {
                                
                                if (CFReadStreamGetStatus(requestStream) == kCFStreamStatusError) {
                                    errorHappen = true;
                                    CFStreamError error = CFReadStreamGetError(requestStream);
                                    self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"网络读错误%d",(int)error.error]}];
                                    
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
                    if (!errorHappen) {
                        int32_t minkb = 100;
                        if (index != 0) {
                            minkb = 10;
                        }
                        if ([self videoFileValid:tmpPath minKb:minkb]) {
                            if ([self videoLengthCheck:tmpPath exceptLength:[self.downloadTask.sectionsLengthList[index] longLongValue]]) {
                                NSError *fileE = nil;
                                [self.fileManager removeItemAtPath:destinationPath error:nil];
                                [self.fileManager moveItemAtPath:tmpPath toPath:destinationPath error:&fileE];
                                if (fileE) {
                                    self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey:@"文件移动错误"}];
                                } else {
                                    downloadSuccess = YES;
                                }
                                
                            } else {
                                [self.fileManager removeItemAtPath:tmpPath error:nil];
                                self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeTransferError userInfo:@{NSLocalizedDescriptionKey: @"文件校验失败"}];
                            }
                        } else {
                            [self.fileManager removeItemAtPath:tmpPath error:nil];
                            self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeTransferError userInfo:@{NSLocalizedDescriptionKey: @"文件大小错误"}];
                        }
                        
                        
                    }
                }
            }
            CFRelease(allHeader);
            CFRelease(myResponse);
        }
    }
    CFRelease(messageRef);
    CFRelease(writeRef);
    CFRelease(requestStream);
    
    if (self.downloadTask.state == ZZDownloadStateDownloading) {
        self.downloadTask.state = ZZDownloadStateWaiting;
    }
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
    self.downloadTask.state = ZZDownloadStateFail;
    self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOFullError userInfo:@{NSLocalizedDescriptionKey: @"磁盘已满"}];
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
        self.downloadTask.lastestError = [NSError errorWithDomain:ZZDownloadTaskErrorDomain code:ZZDownloadTaskErrorTypeIOError userInfo:@{NSLocalizedDescriptionKey:@"文件缓存移动错误"}];
        return NO;
    } else {
        NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:destinationPath error:nil];
        long long x = [dict[NSFileSize] longLongValue];
        self.downloadTask.sectionsLengthList[index] = [NSNumber numberWithUnsignedInteger:x];
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
- (BOOL)videoLengthCheck:(NSString *)filePath exceptLength:(long long)exceptLength
{
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    long long x = [dict[NSFileSize] longLongValue];
    if (x == exceptLength) {
        return YES;
    }
    return NO;
}

- (BOOL)videoFileValid:(NSString *)filePath minKb:(int32_t)kb
{
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    long long x = [dict[NSFileSize] longLongValue];
    if (x > kb * 1024) {
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

- (NSArray *)getTaskFileNameList:(NSString *)dirPath suffix:(NSString *)suffix
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

