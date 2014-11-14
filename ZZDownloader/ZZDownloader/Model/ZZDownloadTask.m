//
//  ZZTask.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadTask.h"

@interface ZZDownloadTask ()

@property (nonatomic) float progress;
@property (nonatomic) int32_t triedCount;

@end

@implementation ZZDownloadTask

- (id)init
{
    if (self = [super init]) {
        self.command = ZZDownloadAssignedCommandNone;
    }
    return self;
}

#pragma mark - interface
- (void)startWithStartSuccessBlock:(void (^)(void))block;
{
    if (self.command == ZZDownloadAssignedCommandNone || self.command == ZZDownloadAssignedCommandPause || self.command == ZZDownloadAssignedCommandRemove) {
        if (self.state == ZZDownloadStateFail) {
            self.triedCount += 1;
        }
        if (self.state == ZZDownloadStateFail || self.state == ZZDownloadStatePaused || self.state == ZZDownloadStateWaiting) {
            self.command = ZZDownloadAssignedCommandStart;
            block();
        }
    }
}

- (void)pauseWithPauseSuccessBlock:(void (^)(void))block
{
    if (self.command != ZZDownloadAssignedCommandPause) {
        if (self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateDownloading) {
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
    //MARK
    return [[ZZDownloadTask alloc] init];
}

- (float)getProgress
{
    return self.progress;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{};
}

+ (NSValueTransformer *)paramsJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
    } reverseBlock:^(NSDictionary *x) {
        return [NSString stringWithUTF8String:[[NSJSONSerialization dataWithJSONObject:x options:NSJSONWritingPrettyPrinted error:nil] bytes]];
    }];
}

@end
