//
//  BiliDownloadAVEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "BiliDownloadAVEntity.h"
#import "ZZDownloadTaskManagerV2.h"
#import <objc/runtime.h>
@implementation BiliDownloadAVEntity

static NSMutableDictionary *cacheVideoSourceDict;
static NSRecursiveLock *cacheLock;

+ (void)load
{
    cacheLock = [NSRecursiveLock new];
    cacheVideoSourceDict = [NSMutableDictionary dictionary];
#if BILITEST==1
    lock = [NSRecursiveLock new];
#endif
}

+ (const void  **)argvKeysFlags
{
    static const char av_id_f;
    static const char page_f;
    static const char type_tag_f;
    static const char from_f;
    static const char cid_f;
    static const char title_f;
    static const char cover_url_f;
    static const char avname_f;
    static const void* address[8] = {&av_id_f, &page_f, &type_tag_f, &from_f, &cid_f, &title_f, &cover_url_f, &avname_f};
    return address;
}

+ (NSArray *)argvKeys
{
    return @[@"av_id", @"page", @"typeTag", @"from", @"cid", @"title", @"coverUrl", @"avname"];
}

- (NSString *)av_id
{
    return _av_id;
}

- (NSString *)entityType
{
    return @"BiliDownloadAVEntity";
}

- (NSString *)entityKey
{
    return [NSString stringWithFormat:@"av_%@_%d", self.av_id, self.page];
}

- (NSString *)realKey
{
    return [NSString stringWithFormat:@"%@",self.av_id];
}

- (NSString *)aggregationKey
{
    NSAssert(self.av_id, @"aggregationKeyError");
    return [NSString stringWithFormat:@"av_%@", self.av_id];
}

- (NSString *)aggregationType
{
    return @"BiliDownloadAvGroup";
}

- (NSString *)aggregationTitle
{
    return self.avname;
}

- (NSString *)title
{
    return _title;
}

#if BILITEST==1
static NSRecursiveLock *lock;

- (void)writelog:(NSString *)log
{
    [lock lock];
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    path = [path stringByAppendingPathComponent:ZZDownloadTaskManagerTaskDir];
    path = [path stringByAppendingPathComponent:[[self destinationRootDirPath] stringByAppendingPathComponent:@"bililog"]];
    NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if ( !fh ) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    @try {
        [fh seekToEndOfFile];
        [fh writeData:[log dataUsingEncoding:NSUTF8StringEncoding]];
    }
    @catch (NSException *exception) {
        @throw exception;
    }
    @finally {
        [fh closeFile];
    }
    [lock unlock];
}
#endif

- (void)downloadCoverWithDownloadStartBlock:(void (^)(void))block
{
    NSString *coverPath = [[ZZDownloadTaskManagerV2 downloadFolder] stringByAppendingPathComponent:[NSString stringWithFormat:@"av/%@/%@.cover",self.av_id, self.realKey]];
    NSError *ferror;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:[coverPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&ferror]) {
        NSLog(@"Failed to create cache directory at %@", [coverPath stringByDeletingLastPathComponent]);
        return;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:coverPath]) {
        return;
    } else {
        if (!_coverUrl || [_coverUrl isEqual:NSNull.null]) {
            return;
        } else {
            if (block) {
                block();
            }
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:_coverUrl]];
            NSError *error = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:nil error:&error];
            if (error) {
                NSLog(@"download cover error=%@ url=%@",error,urlRequest);
                return;
            }
            [data writeToFile:coverPath options:NSDataWritingAtomic error:nil];
#if BILITEST==1
            [self writelog:[NSString stringWithFormat:@"\ntask:%@ download cover url=%@",self.entityKey, _coverUrl]];
#endif
            return;
        }
    }
}

- (NSString *)getCoverPath
{
    return [[ZZDownloadTaskManagerV2 downloadFolder] stringByAppendingPathComponent:[NSString stringWithFormat:@"av/%@/%@.cover",self.av_id, self.realKey]];
}

+ (NSString *)getEntityKeyWithAvid:(NSString *)av_id page:(int32_t)page
{
    return [NSString stringWithFormat:@"av_%@_%d", av_id, page];
}

- (BOOL)updateSelf
{
    return YES;
//    BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
//    BILI_DOWNLOAD_SOURCE x = YES;
//    if (cfg.preferHighQualityMedia) {
//        x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
//    }
//    else {
//        x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
//    }
//    BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:nil];
//    if (videoSource) {
//        [cacheLock lock];
//        cacheVideoSourceDict[self.entityKey] = videoSource;
//        [cacheLock unlock];
//        self.typeTag = [videoSource tag];
//#if BILITEST==1
//        [self writelog: [NSString stringWithFormat:@"\ntask:%@ updateSelf: typeTag=%@",self.entityKey,self.typeTag]];
//#endif
//        return YES;
//    }
//    return NO;
}

- (NSString *)uniqueKey
{
    return self.typeTag;
}

- (BOOL)isValid:(ZZDownloadTask *)task
{
    int32_t sectionCount = [self getSectionCount];
    BOOL x1 = task.sectionsLengthList.count == sectionCount;
    BOOL x2 = task.sectionsDownloadedList.count == sectionCount;
    BOOL x3 = (task.argv[@"typeTag"] != NSNull.null) && [task.argv[@"typeTag"] isEqualToString:self.typeTag];
    if (!x1 || !x2 || !x3) {
#if BILITEST==1
        [self writelog:[NSString stringWithFormat:@"\ntask:%@ not valid argv=%@",task.key,task.argv]];
#endif
        return NO;
    }
#if BILITEST==1
    [self writelog:[NSString stringWithFormat:@"\ntask:%@ valid argv=%@",task.key,task.argv]];
#endif
    return YES;
}

- (NSString *)destinationDirPath
{
    return [NSString stringWithFormat:@"av/%@/%d/%@", self.av_id, (int32_t)self.page, self.typeTag];
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
    return @"";
}

- (NSUInteger)getSectionTotalLengthWithCount:(NSInteger)index
{
    return 0;
}

- (void)downloadDanmakuWithDownloadStartBlock:(void (^)(void))block
{
}

- (NSString *)getDanmakuPath
{
    return [[ZZDownloadTaskManagerV2 downloadFolder] stringByAppendingPathComponent:[[self destinationDirPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.danmaku", self.entityKey]]];
}


- (NSString *)destinationRootDirPath
{
    return [NSString stringWithFormat:@"av/%@/%d", self.av_id, (int32_t)self.page];
}

- (int32_t)getSectionCount
{
    return 0;
}

@end
