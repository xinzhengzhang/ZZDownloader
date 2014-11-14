//
//  ZZDownloadNotifyManager.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadNotifyQueue.h"
#import "ZZDownloadTaskManager.h"

@interface ZZDownloadNotifyManager ()

@property (nonatomic, strong) NSMutableDictionary *allTaskInfoDict;

@end

@implementation ZZDownloadNotifyManager
+ (id)shared
{
    static ZZDownloadNotifyManager *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[ZZDownloadNotifyManager alloc] init];
        queue.allTaskInfoDict = [NSMutableDictionary dictionary];
        ZZDownloadMessage *message = [[ZZDownloadMessage alloc] init];
        message.command = ZZDownloadMessageCommandNeedBuild;
        [queue addOp:message];
    });
    return queue;
}

- (void)addOp:(ZZDownloadMessage *)message
{
    [[ZZDownloadNotifyQueue shared] addOperationWithBlock:^{
        [self doOp:message];
    }];
}

- (void)doOp:(ZZDownloadMessage *)message
{
    if (message.command == ZZDownloadMessageCommandNeedBuild) {
        [self buildAllTaskInfo];
        return;
    }
    ZZDownloadTask *existedTask = self.allTaskInfoDict[message.key];
    if (existedTask) {
        if (message.command == ZZDownloadMessageCommandNeedUpdateInfo) {
            [existedTask updateSelfWithActionBlock:^{
                // update self
            }];
        } else if (message.command == ZZDownloadMessageCommandNeedNotifyUI) {
            // send notification
        }
        
    }
}

- (void)buildAllTaskInfo
{
    [self.allTaskInfoDict removeAllObjects];
    NSArray *filePathList = [ZZDownloadTaskManager getBiliTaskFilePathList];
    NSError *error;
    for (NSString *filePath in filePathList) {
        NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
        if (error) {
            NSLog(@"%@", error);
            continue;
        }
        NSDictionary *rdict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (error) {
            NSLog(@"%@", error);
            continue;
        }
        ZZDownloadTask *rtask = [MTLJSONAdapter modelOfClass:[ZZDownloadTask class] fromJSONDictionary:rdict error:&error];
        if (error) {
            NSLog(@"%@", error);
            continue;
        }
        if (rtask.key) {
            self.allTaskInfoDict[rtask.key] = rtask;
        }
    }
}

@end
