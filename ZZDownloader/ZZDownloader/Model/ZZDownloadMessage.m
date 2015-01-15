//
//  ZZDownloadMessage.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadMessage.h"

@implementation ZZDownloadMessage

- (id)copyWithZone:(NSZone *)zone
{
    ZZDownloadMessage *message = [[ZZDownloadMessage allocWithZone:zone] init];
    message.command = self.command;
    message.key = [self.key copyWithZone:zone];
    message.task = [self.task copyWithZone:zone];
    message.block = self.block;
    return message;
}

@end
