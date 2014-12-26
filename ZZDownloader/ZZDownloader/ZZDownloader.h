//
//  ZZDownloader.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/12/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "BiliDownloadManager.h"
#import "EXTScope.h"
#import "ZZDownloadTaskCFNetworkOperation.h"
#import "ZZDownloadBackgroundSessionManager.h"
#define ZZDownloadQueueAssert(x) NSAssert([[[NSOperationQueue currentQueue] name] isEqualToString:x], x);

@interface ZZDownloader : NSObject

@end
