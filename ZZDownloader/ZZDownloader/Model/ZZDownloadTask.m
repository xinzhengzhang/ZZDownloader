//
//  ZZTask.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadTask.h"

@interface ZZDownloadTask ()

@end

@implementation ZZDownloadTask

- (id)init
{
    if (self = [super init]) {
        self.command = ZZDownloadAssignedCommandNone;
        self.state = ZZDownloadStateNothing;
    }
    return self;
}

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

#pragma mark - interface
- (void)startWithStartSuccessBlock:(void (^)(void))block;
{
    if (self.command == ZZDownloadAssignedCommandNone || self.command == ZZDownloadAssignedCommandPause || self.command == ZZDownloadAssignedCommandRemove) {
        if (self.state == ZZDownloadStateFail) {
            self.triedCount += 1;
        }
        if (self.state == ZZDownloadStateNothing|| self.state == ZZDownloadStateFail || self.state == ZZDownloadStatePaused || self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateRemoved) {
            self.command = ZZDownloadAssignedCommandStart;
            self.state = ZZDownloadStateWaiting;
            block();
        }
    }
}

- (void)pauseWithPauseSuccessBlock:(void (^)(void))block
{
    if (self.command != ZZDownloadAssignedCommandPause && self.command != ZZDownloadAssignedCommandRemove) {
        if (self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateDownloading || self.state == ZZDownloadStateNothing) {
            self.command = ZZDownloadAssignedCommandPause;
            block();
        }
    }
}

- (void)removeWithRemoveSuccessBlock:(void (^)(void))block
{
    if (self.command != ZZDownloadAssignedCommandRemove) {
        self.command = ZZDownloadAssignedCommandRemove;
        block();
    }
}

+ (ZZDownloadTask *)buildTaskFromDisk:(NSDictionary *)params
{
    ZZDownloadTask *t = [[ZZDownloadTask alloc] init];
    t.argv = params;
    return t;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{};
}

+ (NSValueTransformer *)argvJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    } reverseBlock:^(NSDictionary *x) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:x options:0 error:nil];
        NSString *t = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
        return t;
    }];
}

+ (NSValueTransformer *)sectionsLengthListJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        NSArray *x = [str componentsSeparatedByString:@","];
        return [NSMutableArray arrayWithArray:x];
    } reverseBlock:^(NSArray *x) {
        return [x componentsJoinedByString:@","];
    }];
}

+ (NSValueTransformer *)sectionsDownloadedListJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        NSArray *x = [str componentsSeparatedByString:@","];
        return [NSMutableArray arrayWithArray:x];
    } reverseBlock:^(NSArray *x) {
        return [x componentsJoinedByString:@","];
    }];
}

@end
