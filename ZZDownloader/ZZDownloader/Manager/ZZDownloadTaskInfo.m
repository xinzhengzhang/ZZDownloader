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

- (id)init
{
    if (self = [super init]) {
        self.index = -1;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    ZZDownloadTaskInfo *info = [[ZZDownloadTaskInfo allocWithZone:zone] init];
    info.state = self.state;
    info.command = self.command;
    info.key = [self.key copyWithZone:zone];
    info.entityType = [self.entityType copyWithZone:zone];
    info.argv = [self.argv copyWithZone:zone];
    info.lastestError = [self.lastestError copyWithZone:zone];
    info.triedCount = self.triedCount;
    info.sectionsContentTime = [self.sectionsContentTime copyWithZone:zone];
    info.sectionsDownloadedList = [self.sectionsDownloadedList copyWithZone:zone];
    info.sectionsLengthList = [self.sectionsLengthList copyWithZone:zone];
    info.index = self.index;
    return info;
}

- (NSArray *)sectionsDownloadedList
{
    if (!_sectionsDownloadedList) {
        _sectionsDownloadedList = [NSArray array];
    }
    return _sectionsDownloadedList;
}

- (NSArray *)sectionsLengthList
{
    if (!_sectionsLengthList) {
        _sectionsLengthList = [NSArray array];
    }
    return _sectionsLengthList;
}

- (NSArray *)sectionsContentTime
{
    if (!_sectionsContentTime) {
        _sectionsContentTime = [NSArray array];
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
    long long lastest = 0;
    for (NSNumber *n in self.sectionsLengthList) {
        long long x = [n longLongValue];
        if (x == 0) {
            x = lastest;
        } else {
            lastest = x;
        }
        t += x;
    }
    return t;
}

- (long long)getDownloadedLength
{
    long long t = 0;
    for (NSNumber *n in [self.sectionsDownloadedList copy]) {
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
    if (x < 0) {
        x = 0;
    }
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

- (NSString *)getUILabelText
{
    if (self.command == ZZDownloadAssignedCommandRemove) {
        return @"任务移除中(･･;)";
    }
    if (self.command == ZZDownloadAssignedCommandInterruptPaused) {
        return @"任务中断中(･･;)";
    }
    if (self.command == ZZDownloadAssignedCommandPause) {
        return @"任务暂停中(･･;)";
    }
    
    float_t d,t;
    d = [self getDownloadedLength] * 1.0/1024/1024;
    t = [self getTotalLength]*1.0/1024/1024;
    
    NSString *dString,*tString;
    if (d <= 0.0f) {
        dString = @"-";
    }
    else {
        dString = [[NSString alloc]initWithFormat:@"%.1f",d];
    }
    if (t <= 0.0f) {
        tString = @"-";
    }
    else {
        tString = [[NSString alloc]initWithFormat:@"%.1f",t];
    }

    if (self.command == ZZDownloadAssignedCommandStart) {
        if (self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateNothing) {
            return [NSString stringWithFormat:@"等待中: %@/%@MB",dString, tString];
        } else if (self.state == ZZDownloadStateDownloadingDanmaku) {
            return @"缓存弹幕中";
        } else if (self.state == ZZDownloadStateDownloadingCover) {
            return @"缓存封面中";
        }  else if (self.state == ZZDownloadStateParsing) {
            return @"地址解析中...";
        } else if (self.state == ZZDownloadStateFail) {
            return @"下载失败等待重新开始";
        }
    }
    if (self.command == ZZDownloadAssignedCommandNone) {
        if (self.state == ZZDownloadStateNothing) {
            return @"点击开始任务 =_=";
        } else if (self.state == ZZDownloadStateRealPaused){
            return [NSString stringWithFormat:@"已暂停：%@/%@MB",dString, tString];
        } else if (self.state == ZZDownloadStateInterrputPaused) {
            return [NSString stringWithFormat:@"已中断：%@/%@MB",dString, tString];
        } else if (self.state == ZZDownloadStateFail) {
            NSString *failDesc;
            if (self.lastestError) {
                if (self.lastestError.userInfo[@"originError"]) {
                    failDesc = [self.lastestError.userInfo[@"originError"] localizedDescription];
                } else {
                    failDesc = [self.lastestError localizedDescription];
                }
            }
            return [NSString stringWithFormat:@"失败原因:%@",failDesc?:@"未知"];
        } else if (self.state == ZZDownloadStateWaiting) {
            return [NSString stringWithFormat:@"等待中: %@/%@MB",dString, tString];
        } else if (self.state == ZZDownloadStateDownloading) {
            return [NSString stringWithFormat:@"缓存中: %@/%@MB",dString, tString];
        } else if (self.state == ZZDownloadStateDownloadingDanmaku) {
            return @"缓存弹幕中";
        } else if (self.state == ZZDownloadStateDownloadingCover) {
            return @"缓存封面中";
        } else if (self.state ==ZZDownloadStateDownloaded) {
            return [NSString stringWithFormat:@"缓存完成：%@MB",tString];
        } else if (self.state == ZZDownloadStateInvalid) {
            NSString *failDesc;
            if (self.lastestError) {
                if (self.lastestError.userInfo[@"originError"]) {
                    failDesc = [self.lastestError.userInfo[@"originError"] localizedDescription];
                } else {
                    failDesc = [self.lastestError localizedDescription];
                }
            }
            return [NSString stringWithFormat:@"无效原因:%@",failDesc?:@"未知"];
        } else if (self.state == ZZDownloadStateParsing) {
            return @"地址解析中...";
        }
    }
    return @"未知状态";
}

- (int8_t)getPressedCommand
{
    if (self.command == ZZDownloadAssignedCommandRemove) {
        return 0;
    }
    if (self.command == ZZDownloadAssignedCommandInterruptPaused) {
        return 0;
    }
    if (self.command == ZZDownloadAssignedCommandPause) {
        return 0;
    }
    if (self.command == ZZDownloadAssignedCommandStart) {
        return 2;
    }

    if (self.command == ZZDownloadAssignedCommandNone) {
        if (self.state == ZZDownloadStateNothing || self.state == ZZDownloadStateRealPaused || self.state == ZZDownloadStateInterrputPaused || self.state == ZZDownloadStateInvalid) {
            return 1;
        } else if (self.state == ZZDownloadStateWaiting || self.state == ZZDownloadStateDownloading || self.state == ZZDownloadStateDownloadingDanmaku || self.state == ZZDownloadStateDownloadingCover || self.state == ZZDownloadStateParsing || self.state == ZZDownloadStateFail) {
            return 2;
        } else if (self.state == ZZDownloadStateDownloaded) {
            return 3;
        }
    }
    return 0;
}

- (BOOL)isPostiveState
{
    if (self.state == ZZDownloadStateDownloading && self.command == ZZDownloadAssignedCommandNone) {
        return YES;
    }
    return NO;
}

- (BOOL)allowRemove
{
    return self.command != ZZDownloadAssignedCommandRemove;
}

- (BOOL)isDownloaded
{
    return self.state == ZZDownloadStateDownloaded;
}

@end
