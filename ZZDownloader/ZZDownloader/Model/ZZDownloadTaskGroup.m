//
//  ZZDownloadTaskGroup.m
//  ibiliplayer
//
//  Created by zhangxinzheng on 11/25/14.
//  Copyright (c) 2014 Zhang Rui. All rights reserved.
//

#import "ZZDownloadTaskGroup.h"

@implementation ZZDownloadTaskGroup

- (id)init
{
    if (self = [super init]) {
        self.state = ZZDownloadTaskGroupStateWaiting;
        self.taskInfoDict = [NSMutableDictionary dictionary];
    }
    return self;
}

@end
