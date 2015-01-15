//
//  ZZDownloadTaskCFNetworkOperation.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 12/12/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTask.h"
#import "ZZdownloadTaskOperationHeader.h"



@interface ZZDownloadTaskCFNetworkOperation : NSOperation

@property (nonatomic, weak) id <ZZDownloadTaskOperationDelegate> delegate;
@property (nonatomic, readonly) ZZTaskOperationState state;
- (id)initWithTask:(ZZDownloadTask *)task;
+ (NSString *)getBackgroundDownloadTempPath:(NSString *)key section:(int32_t)section typetag:(NSString *)typeTag;
- (NSString *)key;
- (void)pause;
- (void)remove;
@end

