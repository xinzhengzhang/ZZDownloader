//
//  ZZDownloadOpOperation.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadOpOperation.h"

@interface ZZDownloadOpOperation ()

@property (nonatomic, strong) ZZDownloadOperation *operation;

@end

@implementation ZZDownloadOpOperation

- (id)initWithOperation:(ZZDownloadOperation *)operation
{
    if (self = [super init]) {
        self.operation = operation;
    }
    return self;
}

- (void)main
{
    ZZDownloadTask *task = [self.dataSource getDownloadTaskByClass:self.operation.taskClass withId:self.operation.tId withKey:self.operation.key];
    ZZDownloadCommand command = self.operation.command;
    switch (command) {
        case ZZDownloadCommandBuild:
            [self.delegate build];
            break;
        case ZZDownloadCommandCheck:
            [self.delegate checkTask:task];
            break;
        case ZZDownloadCommandRemove:
            [self.delegate removeTask:task];
            break;
        case ZZDownloadCommandResume:
            [self.delegate resumeTask:task];
            break;
        case ZZDownloadCommandStart:
            [self.delegate startTask:task];
            break;
        case ZZDownloadCommandStop:
            [self.delegate stopTask:task];
            break;
        default:
            break;
    }
}

@end
