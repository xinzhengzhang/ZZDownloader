//
//  ZZTask.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadTask.h"

NSString * const ZZDownloadTaskErrorDomain = @"ZZDownloadTaskErrorDomain";

@interface ZZDownloadTask ()

@end

@implementation ZZDownloadTask

- (id)init
{
    if (self = [super init]) {
        self.command = ZZDownloadAssignedCommandNone;
        self.state = ZZDownloadStateNothing;
        self.taskArrangeType = ZZDownloadTaskArrangeTypeUnArranged;
    }
    return self;
}

- (ZZDownloadBaseEntity *)recoverEntity
{
    volatile NSString *type = self.entityType;
    if ([ZZDownloadValidEntity containsObject:type]) {
        Class class = NSClassFromString((NSString *)type);
        ZZDownloadBaseEntity *entity = [[class alloc] init];
        [entity setValuesForKeysWithDictionary:self.argv];
        return entity;
    }
    return nil;
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

- (NSMutableArray *)sectionsContentTime
{
    if (!_sectionsContentTime) {
        _sectionsContentTime = [NSMutableArray array];
    }
    return _sectionsContentTime;
}

- (NSArray *)getSectionsContentTimes
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

#pragma mark - interface
- (void)startWithStartSuccessBlock:(void (^)(void))block;
{
    if (self.command == ZZDownloadAssignedCommandNone || self.command == ZZDownloadAssignedCommandPause || self.command == ZZDownloadAssignedCommandRemove || self.command == ZZDownloadAssignedCommandInterruptPaused) {
        if (self.state == ZZDownloadStateFail ) {
            self.triedCount += 1;
        }
        if (self.state == ZZDownloadStateInvalid) {
            self.triedCount = 0;
            self.state = ZZDownloadStateNothing;
        }
        if (self.state == ZZDownloadStateNothing|| self.state == ZZDownloadStateFail || self.state == ZZDownloadStateRealPaused || self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateRemoved || self.state == ZZDownloadStateInterrputPaused) {
            self.command = ZZDownloadAssignedCommandStart;
            self.state = ZZDownloadStateWaiting;
            block();
        }
    }
}

- (void)pauseWithPauseSuccessBlock:(void (^)(void))block ukeru:(BOOL)ukeru
{
    if (self.command != ZZDownloadAssignedCommandPause && self.command != ZZDownloadAssignedCommandRemove) {
        if (self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateDownloading || self.state == ZZDownloadStateNothing || self.state == ZZDownloadStateParsing || self.state == ZZDownloadStateDownloadingCover || self.state == ZZDownloadStateDownloadingDanmaku || self.state == ZZDownloadStateFail) {
            if (ukeru) {
                self.command = ZZDownloadAssignedCommandInterruptPaused;
            } else {
                self.command = ZZDownloadAssignedCommandPause;
            }
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

+ (NSValueTransformer *)sectionsContentTimeJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        NSArray *x = [str componentsSeparatedByString:@","];
        NSMutableArray *t = [NSMutableArray array];
        for (NSString *tt in x){
            [t addObject:[NSNumber numberWithInteger:[tt integerValue]]];
        }
        return t;
    } reverseBlock:^(NSArray *x) {
        NSMutableArray *t = [NSMutableArray array];
        for (NSNumber *num in x) {
            [t addObject:[NSString stringWithFormat:@"%@",num]];
        }
        return [t componentsJoinedByString:@","];
    }];
}

+ (NSValueTransformer *)lastestErrorJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        NSError *error = nil;
        if (str) {
            error = [NSKeyedUnarchiver unarchiveObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding]];
        }
        return error;
    } reverseBlock:^(NSError *error) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:error];
        return [NSString stringWithUTF8String:[data bytes]];
    }];
}
@end
