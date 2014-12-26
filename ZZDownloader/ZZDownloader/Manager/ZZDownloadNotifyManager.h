//
//  ZZDownloadNotifyManager.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadMessage.h"

extern void * const ZZDownloadStateChangedContext;
extern NSString * const ZZDownloadTaskNotifyUiNotification;
extern NSString * const ZZDownloadTaskDiskSpaceWarningNotification;
extern NSString * const ZZDownloadTaskDiskSpaceErrorNotification;
extern NSString * const ZZDownloadTaskNetWorkChangedInterruptNotification;
extern NSString * const ZZDownloadTaskNetWorkChangedResumeNotification;

@interface ZZDownloadNotifyManager : NSObject

+ (id)shared;
- (void)addOp:(ZZDownloadMessage *)message;

@end
