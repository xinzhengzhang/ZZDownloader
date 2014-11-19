//
//  ZZDownloadMessage.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Mantle/Mantle.h>
#import "ZZDownloadTask.h"
#import "ZZDownloadBaseEntity.h"

typedef NS_ENUM(NSUInteger, ZZDownloadMessageCommand) {
    ZZDownloadMessageCommandNeedUpdateInfo = 1034,
    ZZDownloadMessageCommandNeedNotifyUI,
    ZZDownloadMessageCommandNeedNotifyUIByCheck,
    ZZDownloadMessageCommandRemoveTaskInfo,
    ZZDownloadMessageCommandNeedBuild
};

@interface ZZDownloadMessage : NSObject

@property (nonatomic) ZZDownloadMessageCommand command;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) ZZDownloadTask *task;
@property (nonatomic, copy) void (^block)(id);

@end
