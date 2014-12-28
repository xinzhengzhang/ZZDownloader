//
//  BiliDownloadAVEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "BiliDownloadAVEntity.h"
//#import "BiliPlayerConfig.h"
//#import "BiliVideoResolver.h"
//#import "BiliVideoSource.h"
#import "ZZDownloadTaskManagerV2.h"

@implementation BiliDownloadAVEntity
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
+ (void)load
{
    lock = [NSRecursiveLock new];
}

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
    [fh seekToEndOfFile];
    [fh writeData:[log dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
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

//- (NSString *)getTypeTag:(BOOL)focusUpdate
//{
//    if (focusUpdate || !self.typeTag || [self.typeTag isEqual:NSNull.null]) {
////        BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
////        BILI_DOWNLOAD_SOURCE x = YES;
////        if (cfg.preferHighQualityMedia) {
////            x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
////        }
////        else {
////            x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
////        }
////        BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:nil];
////        if (videoSource) {
////            self.typeTag = [videoSource tag];
////#if BILITEST==1
////            [self writelog: [NSString stringWithFormat:@"\ntask:%@ assignTypetag:%@",self.entityKey,self.typeTag]];
////#endif
////        }
//        return self.typeTag;
//    } else {
//        return self.typeTag;
//    }
//}

- (BOOL)updateSelf
{
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
//        self.typeTag = [videoSource tag];
//#if BILITEST==1
//        [self writelog: [NSString stringWithFormat:@"\ntask:%@ assignTypetag:%@",self.entityKey,self.typeTag]];
//#endif
//    }
    return YES;

}

- (BOOL)isValid:(ZZDownloadTask *)task
{
    int32_t sectionCount = [self getSectionCount];
    BOOL x1 = task.sectionsLengthList.count == sectionCount;
    BOOL x2 = task.sectionsDownloadedList.count == sectionCount;
    BOOL x3 = (task.argv[@"typeTag"] != NSNull.null) && [task.argv[@"typeTag"] isEqualToString:self.typeTag];
    if (!x1 || !x2 || !x3) {
        return NO;
    }
    return YES;
}

- (NSString *)uniqueKey
{
    return self.typeTag;
}

- (NSString *)destinationDirPath
{
    return [NSString stringWithFormat:@"av/%@/%d/%@", self.av_id, (int32_t)self.page, self.typeTag];
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
//    BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
//    BILI_DOWNLOAD_SOURCE x = YES;
//    if (cfg.preferHighQualityMedia) {
//        x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
//    }
//    else {
//        x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
//    }
//    BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:[self getTypeTag:NO]];
//
//    if (videoSource.mediaSource.url) {
//#if BILITEST==1
//        [self writelog:[NSString stringWithFormat:@"\ntask:%@ parseUrl section:%lu url:%@",self.entityKey,(long)index, videoSource.mediaSource.url]];
//#endif
//        return videoSource.mediaSource.url;
//    } else if (videoSource.mediaSource.segmentList.count > index){
//#if BILITEST==1
//        [self writelog:[NSString stringWithFormat:@"\ntask:%@ parseUrl section:%lu url:%@",self.entityKey,(long)index, [videoSource.mediaSource urlOfSegment:(int32_t)index]]];
//#endif
//        return [videoSource.mediaSource urlOfSegment:(int32_t)index];
//    } else {
        return nil;
//    }
}

- (NSUInteger)getSectionTotalLengthWithCount:(NSInteger)index
{
//    BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
//    BILI_DOWNLOAD_SOURCE x = YES;
//    if (cfg.preferHighQualityMedia) {
//        x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
//    }
//    else {
//        x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
//    }
//    BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:[self getTypeTag:NO]];
//    
//    if (videoSource.mediaSource.url) {
//#if BILITEST==1
//        [self writelog:[NSString stringWithFormat:@"\ntask:%@ getTotalLength section:%ld length:%ld",self.entityKey,(long)index, (long)videoSource.mediaSource.totalDuration]];
//#endif
//        return videoSource.mediaSource.totalDuration;
//    } else if (videoSource.mediaSource.segmentList.count > index){
//#if BILITEST==1
//        [self writelog:[NSString stringWithFormat:@"\ntask:%@ getTotalLength section:%lu length:%lu",self.entityKey,(long)index, (long)[(BiliMediaSegment*)videoSource.mediaSource.segmentList[index] duration]]];
//#endif
//        return [(BiliMediaSegment*)videoSource.mediaSource.segmentList[index] duration];
//    } else {
        return 0;
//    }
}

- (void)downloadDanmakuWithDownloadStartBlock:(void (^)(void))block
{
    NSString *danmakuPath = [[ZZDownloadTaskManagerV2 downloadFolder] stringByAppendingPathComponent:[[self destinationDirPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.danmaku", self.entityKey]]];
    NSError *ferror;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:[danmakuPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&ferror]) {
        NSLog(@"Failed to create cache directory at %@", [danmakuPath stringByDeletingLastPathComponent]);
        return;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:danmakuPath]) {
        return;
    } else {
        if (!self.cid || [self.cid isEqual:NSNull.null]) {
            return;
        } else {
            if (block) {
                block();
            }
//            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:BILI_API_GET_DANMAKU_LIST([self.cid intValue])]];
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]];
            NSError *error = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:nil error:&error];
            if (error) {
                NSLog(@"download danmaku error=%@ url=%@",error, urlRequest);
            
                return;
            }
            [data writeToFile:danmakuPath options:NSDataWritingAtomic error:nil];
            return;
        }
    }
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
//    BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
//    BILI_DOWNLOAD_SOURCE x = YES;
//    if (cfg.preferHighQualityMedia) {
//        x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
//    }
//    else {
//        x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
//    }
//    
//    BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:[self getTypeTag:NO]];
//    if (videoSource.mediaSource.url) {
//#if BILITEST==1
//        [self writelog:[NSString stringWithFormat:@"\ntask:%@ getSectionCount sections:%d",self.entityKey,1]];
//#endif
        return 1;
//    } else {
//#if BILITEST==1
//        [self writelog:[NSString stringWithFormat:@"\ntask:%@ getSectionCount sections:%d",self.entityKey,(int32_t)videoSource.mediaSource.segmentList.count]];
//#endif
//        return (int32_t)videoSource.mediaSource.segmentList.count;
//    }
}

@end
