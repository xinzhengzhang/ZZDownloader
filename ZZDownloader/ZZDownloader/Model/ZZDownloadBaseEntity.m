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

+ (const void  **)argvKeysFlags
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return NULL;
}

+ (NSArray *)argvKeys
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @[];
}

- (NSString *)title
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSUInteger)getSectionTotalLengthWithCount:(NSInteger)index
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return 0;
}

- (void)downloadCoverWithDownloadStartBlock:(void (^)(void))block
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
}

- (NSString *)aggregationKey
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)aggregationTitle
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)aggregationType
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)realKey
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)uniqueKey
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (BOOL)updateSelf
{
    return YES;
}

- (BOOL)isValid:(ZZDownloadTask *)task
{
    return YES;
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

- (void)downloadDanmakuWithDownloadStartBlock:(void (^)(void))block
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
}

- (NSString *)getDanmakuPath
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (NSString *)getCoverPath
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

- (int32_t)getSectionCount
{
    return 0;
}

- (NSString *)destinationRootDirPath
{
    NSAssert(nil, @"sub class has not implement ZZDownloadBaseEntity");
    return @"";
}

@end
