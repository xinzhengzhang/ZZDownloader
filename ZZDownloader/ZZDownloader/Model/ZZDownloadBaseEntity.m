//
//  ZZDownloadBaseEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "ZZDownloadBaseEntity.h"

@implementation ZZDownloadBaseEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{};
}

- (NSString *)entityType
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)entityKey
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)destinationDirPath
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)danmakuPath
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (int32_t)getSectionCount
{
    return 0;
}
@end
