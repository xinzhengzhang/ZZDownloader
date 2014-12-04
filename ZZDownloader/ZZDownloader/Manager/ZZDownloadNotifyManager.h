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

@interface ZZDownloadNotifyManager : NSObject

+ (id)shared;
- (void)addOp:(ZZDownloadMessage *)message;
@end
