//
//  ZZDownloadMessageOperation.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadMessageOperation.h"

@interface ZZDownloadMessageOperation ()

@property (nonatomic, strong) ZZDownloadMessage *message;

@end

@implementation ZZDownloadMessageOperation

- (id)initWithMessageOperation:(ZZDownloadMessage *)message
{
    if (self = [super init]) {
        self.message = message;
    }
    return self;
}

- (void)main
{
    ZZDownloadTask *task = [self.dataSource getMessage:self.message.taskClass withId:self.message.tId];
    switch (self.message.command) {
        case ZZDownloadMessageCommandNeedBuild:
            [self.delegate build];
            break;
        case ZZDownloadMessageCommandNeedNotifyUI:
            [self.delegate notifySendNotificationWithTask:task];
            break;
        case ZZDownloadMessageCommandNeedUpdateInfo:
            [self.delegate notifyUpdateInfoWithTask:task];
            break;
        default:
            break;
    }
}

@end
