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

#pragma mark - interface
- (void)startWithStartSuccessBlock:(void (^)(void))block;
{
    if (self.command == ZZDownloadAssignedCommandNone || self.command == ZZDownloadAssignedCommandPause || self.command == ZZDownloadAssignedCommandRemove) {
        if (self.state == ZZDownloadStateFail) {
            self.triedCount += 1;
        }
        // 手贱要是有人删已下载文件
        if (self.state == ZZDownloadStateNothing|| self.state == ZZDownloadStateFail || self.state == ZZDownloadStatePaused || self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateRemoved /*|| self.state == ZZDownloadStateDownloaded*/) {
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

@end
