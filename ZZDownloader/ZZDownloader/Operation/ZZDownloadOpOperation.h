//
//  ZZDownloadOpOperation.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTask.h"
#import "ZZDownloadOperation.h"

@protocol ZZDownloadOpOperationDataSource <NSObject>

@required
- (ZZDownloadTask *)getDownloadTaskByClass:(Class<MTLJSONSerializing>)taskClass withId:(NSString *)tId withKey:(NSString *)key;

@end

@protocol ZZDownloadOpOperationDelegate <NSObject>

@required
- (void)startTask:(ZZDownloadTask *)task;
- (void)stopTask:(ZZDownloadTask *)task;
- (void)resumeTask:(ZZDownloadTask *)task;
- (void)removeTask:(ZZDownloadTask *)task;
- (void)checkTask:(ZZDownloadTask *)task;
- (void)build;

@end

@interface ZZDownloadOpOperation : NSOperation

- (id)initWithOperation:(ZZDownloadOperation *)operation;

@property (nonatomic, weak) id <ZZDownloadOpOperationDataSource> dataSource;
@property (nonatomic, weak) id <ZZDownloadOpOperationDelegate> delegate;

@end
