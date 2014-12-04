//
//  ZZDownloadTaskInfo.m
//  Pods
//
//  Created by zhangxinzheng on 11/20/14.
//
//

#import "ZZDownloadTaskInfo.h"
#import "ZZDownloadTask+Helper.h"

@implementation ZZDownloadTaskInfo
- (NSMutableArray *)sectionsDownloadedList
{
    if (!_sectionsDownloadedList) {
        _sectionsDownloadedList = [NSMutableArray array];
    }
    return _sectionsDownloadedList;
}

- (NSMutableArray *)sectionsLengthList
{
    if (!_sectionsLengthList) {
        _sectionsLengthList = [NSMutableArray array];
    }
    return _sectionsLengthList;
}

- (NSMutableArray *)sectionsContentTime
{
    if (!_sectionsContentTime) {
        _sectionsContentTime = [NSMutableArray array];
    }
    return _sectionsContentTime;
}

- (NSArray *)getSectionsTotalLength
{
    return [self.sectionsContentTime copy];
}

- (long long)getTotalLength
{
    long long t = 0;
    for (NSNumber *n in self.sectionsLengthList) {
        long long x = [n longLongValue];
        t += x;
    }
    return t;
}

- (long long)getDownloadedLength
{
    long long t = 0;
    for (NSNumber *n in self.sectionsDownloadedList) {
        long long x = [n longLongValue];
        t += x;
    }
    return t;
}

- (CGFloat)getProgress
{
    if (self.state == ZZDownloadStateDownloaded) {
        return 1.0f;
    }
    CGFloat x = [self getDownloadedLength] * 1.0 / ([self getTotalLength] ?: 1);
    return x >= 1.0f ? 0.99 : x;
}

- (ZZDownloadBaseEntity *)recoverEntity
{
    NSString *type = self.entityType;
    if ([ZZDownloadValidEntity containsObject:type]) {
        Class class = NSClassFromString(type);
        ZZDownloadBaseEntity *entity = [[class alloc] init];
        [entity setValuesForKeysWithDictionary:self.argv];
        return entity;
    }
    return nil;
}

@end
