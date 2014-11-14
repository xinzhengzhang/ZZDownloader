//
//  BiliDownloadEpEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "BiliDownloadEpEntity.h"

@implementation BiliDownloadEpEntity

- (NSString *)entityType
{
    return @"BiliDownloadEpEntity";
}

- (NSString *)entityKey
{
    return [NSString stringWithFormat:@"ep_%@", self.ep_id];
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
