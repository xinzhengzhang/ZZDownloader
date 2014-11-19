//
//  ZZDownloadManager.h
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadBaseEntity.h"

extern NSString * const ZZDownloadNotifyUiNotification;

@interface ZZDownloadManager : NSObject

+ (id)shared;

- (void)startEpTaskWithEpId:(NSString *)ep_id;
- (void)pauseEpTaskWithEpId:(NSString *)ep_id;
- (void)removeEpTaskWithEpId:(NSString *)ep_id;
- (void)checkEpTaskWithEpId:(NSString *)ep_id withCompletationBlock:(void (^)(ZZDownloadBaseEntity *))block;
@end
