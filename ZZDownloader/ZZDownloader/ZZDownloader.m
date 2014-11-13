//
//  ZZDownloader.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/12/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloader.h"
#import "ZZDownloadOperation.h"
#import "ZZDownloadTask.h"
#import "TestOperation.h"
@implementation ZZDownloader

+ (void)dosth
{
//    ZZDownloadOperation *x = [ZZDownloadOperation new];
//    x.command = ZZCommandBuild;
//    x.taskClass = [ZZDownloadTask class];
//    x.tId = @"12345";
//    
//    NSDictionary *dict = [MTLJSONAdapter JSONDictionaryFromModel:x];
//    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
//    NSString *jsonString = [NSString stringWithUTF8String:[jsonData bytes]];
//    
//    NSDictionary *rdict = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
////    NSDictionary *rdict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
//    ZZDownloadOperation *rx = [MTLJSONAdapter modelOfClass:[ZZDownloadOperation class] fromJSONDictionary:rdict error:nil];
//    NSLog(@"%@",rx);
    TestOperation *temp = nil;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    for (int i = 0; i<30; i++) {
        TestOperation *op = [[TestOperation alloc] init];
        op.order = i;
//        if (temp) {
//            [op addDependency:temp];
//        }
        [queue addOperation:op];

        temp = op;
        op.completionBlock = ^{
            NSLog(@"finish");
        };

    }

}

@end
