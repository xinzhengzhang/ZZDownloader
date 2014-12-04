//
//  BiliDownloadAVEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "BiliDownloadAVEntity.h"
#import "BiliPlayerConfig.h"
#import "BiliVideoResolver.h"
#import "BiliApi.h"
#import "BiliVideoSource.h"
#import "ZZDownloadTaskManager.h"

@implementation BiliDownloadAVEntity

- (NSString *)entityType
{
    return @"BiliDownloadAvEntity";
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
    return [NSString stringWithFormat:@"av_%@", self.av_id];
}

- (NSString *)aggregationType
{
    return @"BiliDownloadAvGroup";
}

- (NSString *)title
{
    return _title;
}

- (void)downloadCoverWithDownloadStartBlock:(void (^)(void))block
{
    NSString *coverPath = [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[NSString stringWithFormat:@"av/%@/%@.cover",self.av_id, self.realKey]];
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
                return;
            }
            [data writeToFile:coverPath options:NSDataWritingAtomic error:nil];
            return;
        }
    }
}

- (NSString *)getCoverPath
{
    return [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[NSString stringWithFormat:@"av/%@/%@.cover",self.av_id, self.realKey]];
}

+ (NSString *)getEntityKeyWithAvid:(NSString *)av_id page:(int32_t)page
{
    return [NSString stringWithFormat:@"av_%@_%d", av_id, page];
}

- (NSString *)getTypeTag:(BOOL)focusUpdate
{
    if (focusUpdate || !self.typeTag || [self.typeTag isEqual:NSNull.null]) {
        BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
        BILI_DOWNLOAD_SOURCE x = YES;
        if (cfg.preferHighQualityMedia) {
            x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
        }
        else {
            x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
        }
        BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:nil];
        self.typeTag = [videoSource tag];
        return self.typeTag;
    } else {
        return self.typeTag;
    }
}

- (NSString *)destinationDirPath
{
    return [NSString stringWithFormat:@"av/%@/%d/%@", self.av_id, (int32_t)self.page, [self getTypeTag:NO]];
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
    BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
    BILI_DOWNLOAD_SOURCE x = YES;
    if (cfg.preferHighQualityMedia) {
        x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
    }
    else {
        x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
    }
    BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:[self getTypeTag:NO]];

    if (videoSource.mediaSource.url) {
        return videoSource.mediaSource.url;
    } else if (videoSource.mediaSource.segmentList.count > index){
        return [videoSource.mediaSource urlOfSegment:(int32_t)index];
    } else {
        return nil;
    }
}

- (NSUInteger)getSectionTotalLengthWithCount:(NSInteger)index
{
    BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
    BILI_DOWNLOAD_SOURCE x = YES;
    if (cfg.preferHighQualityMedia) {
        x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
    }
    else {
        x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
    }
    BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:[self getTypeTag:NO]];
    
    if (videoSource.mediaSource.url) {
        return videoSource.mediaSource.totalDuration;
    } else if (videoSource.mediaSource.segmentList.count > index){
        return [(BiliMediaSegment*)videoSource.mediaSource.segmentList[index] duration];
    } else {
        return 0;
    }
}

- (void)downloadDanmakuWithDownloadStartBlock:(void (^)(void))block
{
    NSString *danmakuPath = [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[[self destinationDirPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.danmaku", self.entityKey]]];
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
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:BILI_API_GET_DANMAKU_LIST([self.cid intValue])]];
            NSError *error = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:nil error:&error];
            if (error) {
                return;
            }
            [data writeToFile:danmakuPath options:NSDataWritingAtomic error:nil];
            return;
        }
    }
}

- (NSString *)getDanmakuPath
{
    return [[ZZDownloadTaskManager downloadFolder] stringByAppendingPathComponent:[[self destinationDirPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.danmaku", self.entityKey]]];
}


- (NSString *)destinationRootDirPath
{
    return [NSString stringWithFormat:@"av/%@/%d", self.av_id, (int32_t)self.page];
}

- (int32_t)getSectionCount
{
    BiliPlayerConfig *cfg = [BiliPlayerConfig sharedConfig];
    BILI_DOWNLOAD_SOURCE x = YES;
    if (cfg.preferHighQualityMedia) {
        x = BILI_DOWNLOAD_SOURCE_HIGHQUALITY;
    }
    else {
        x = BILI_DOWNLOAD_SOURCE_LOWQUALITY;
    }
    
    BiliVideoSource *videoSource = [BiliVideoResolver mediaSourceForDownloadOfAVID:self.av_id subPage:self.page andSource:x andTypeTag:[self getTypeTag:NO]];
    if (videoSource.mediaSource.url) {
        return 1;
    } else {
        return (int32_t)videoSource.mediaSource.segmentList.count;
    }
}

@end
