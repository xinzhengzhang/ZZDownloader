//
//  TestOperation.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "TestOperation.h"

@implementation TestOperation

- (void)main
{
    int x = arc4random()%5;
    sleep(x);
    NSLog(@"%d", self.order);
}


@end
