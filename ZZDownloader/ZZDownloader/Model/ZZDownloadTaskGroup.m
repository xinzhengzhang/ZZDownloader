//
//  ZZDownloadTaskGroup.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/25/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloadTaskGroup.h"

@implementation ZZDownloadTaskGroup

- (id)init
{
    if (self = [super init]) {
        self.state = ZZDownloadTaskGroupStateWaiting;
        self.taskInfoDict = [NSMutableDictionary dictionary];
        self.index = -1;
    }
    return self;
}

@end
