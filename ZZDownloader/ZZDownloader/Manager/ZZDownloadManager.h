//
//  ZZDownloadManager.h
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import <Foundation/Foundation.h>

@interface ZZDownloadManager : NSObject

+ (id)shared;

- (void)startEpTaskWithEpId:(NSString *)ep_id;
- (void)pauseEpTaskWithEpId:(NSString *)ep_id;
- (void)removeEpTaskWithEpId:(NSString *)ep_id;
- (void)checkEpTaskWithEpId:(NSString *)ep_id;
@end
