//
//  ZZDownloadTaskManager.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTask.h"
#import "ZZDownloadOperation.h"

@interface ZZDownloadTaskManager : NSObject

+ (id)shared;

- (void)addOp:(ZZDownloadOperation *)operation;

@end
