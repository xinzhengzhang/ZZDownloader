//
//  ZZDownloadTaskGroup.m
//  ibiliplayer
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

- (id)copyWithZone:(NSZone *)zone
{
    ZZDownloadTaskGroup *group = [[ZZDownloadTaskGroup allocWithZone:zone] init];
    group.title = [self.title copyWithZone:zone];
    group.coverUrl = [self.coverUrl copyWithZone:zone];
    group.key = [self.key copyWithZone:zone];
    group.realKey = [self.realKey copyWithZone:zone];
    group.state = self.state;
    group.taskInfoDict = [self.taskInfoDict mutableCopyWithZone:zone];
    group.index = self.index;
    return group;
}

- (void)dealloc
{

}
@end
