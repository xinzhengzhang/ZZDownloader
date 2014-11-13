//
//  ZZDownloadMessageOperation.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadMessage.h"
#import "ZZDownloadMessageOperation.h"
#import "ZZDownloadTask.h"

@protocol ZZDownloadMessageOperationDataSource <NSObject>

@required
- (ZZDownloadTask *)getMessage:(Class<MTLJSONSerializing>)taskClass withId:(NSString *)tId;

@end

@protocol ZZDownloadMessageOperationDelegate <NSObject>

@required
- (void)build;
- (void)notifyUpdateInfoWithTask:(ZZDownloadTask *)task;
- (void)notifySendNotificationWithTask:(ZZDownloadTask *)task;
@end

@interface ZZDownloadMessageOperation : NSOperation

- (id)initWithMessageOperation:(ZZDownloadMessage *)message;

@property (nonatomic, weak) id <ZZDownloadMessageOperationDataSource> dataSource;
@property (nonatomic, weak) id <ZZDownloadMessageOperationDelegate> delegate;

@end
