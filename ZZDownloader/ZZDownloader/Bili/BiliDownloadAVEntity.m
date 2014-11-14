//
//  BiliDownloadAVEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "BiliDownloadAVEntity.h"

@implementation BiliDownloadAVEntity

- (NSString *)entityType
{
    return @"BiliDownloadAvEntity";
}

- (NSString *)entityKey
{
    return [NSString stringWithFormat:@"av_%@_%d", self.av_id, self.page];
}

- (NSString *)destinationDirPath
{
    return @"";
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
    return @"";
}

- (NSString *)danmakuPath
{
    return @"";
}

@end
