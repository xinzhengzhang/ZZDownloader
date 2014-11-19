//
//  ZZDownloader.m
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/12/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ZZDownloader.h"
#import "ZZDownloadManager.h"

#import "ZZDownloadBaseEntity.h"
#import "ZZDownloadTask.h"
#import "ZZDownloadNotifyManager.h"
#import "ZZDownloadNotifyQueue.h"

@implementation ZZDownloader

+ (void)dosth
{
    [[ZZDownloadManager shared] startEpTaskWithEpId:@"1000"];
 
    
    return;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xxx:) name:ZZDownloadNotifyUiNotification object:nil];
    
    NSArray *epIds = @[@"100", @"101", @"102", @"103", @"104", @"105"];
    int32_t commands = 10;
    NSUInteger missions = epIds.count;

    
//    int ordercomand[10] = {0,1,2,0,1,2,1,1,0};
//    int ordereps[10] =    {4,4,0,0,0,1,2,4,5};
    int ordercomand[100] = {2,1,1,0,2,0,0,1,0,0,0,2,2,2,1,2,2,2,1,2,2,0,0,2,0,1,2,2,1,1,1,0,0,2,2,2,0,2,1,1,1,1,2,1,0,0,1,0,2,1};
    int ordereps[100] =    {3,4,5,2,1,3,1,3,5,2,0,4,1,4,0,2,4,4,1,0,5,5,2,4,0,5,3,0,2,3,4,5,0,0,5,0,4,2,4,2,4,0,5,0,4,3,4,4,0,3};
    
    for (int i = 0; i < commands; i++) {
        int x = arc4random() %3;
        ordercomand[i] = x;
//        x = ordercomand[i];
        int z = arc4random()%missions;
        NSString *ep = epIds[z];
        ordereps[i] = z;
        ep = epIds[ordereps[i]];
        if (x == 0) {
            NSLog(@"start");
            [[ZZDownloadManager shared] startEpTaskWithEpId:ep];
        } else if (x == 1) {
            NSLog(@"pause");
            [[ZZDownloadManager shared] pauseEpTaskWithEpId:ep];
        } else if (x == 2) {
            NSLog(@"remove");
            [[ZZDownloadManager shared] removeEpTaskWithEpId:ep];
        }
        NSLog(@"%@", ep);
    }
    
    NSLog(@"=====================");
    for (int i = 0; i < 10; i++) {
        printf("%d,",ordercomand[i]);
    }
    printf("\n");
    NSLog(@"=====================");
    for (int i = 0; i < 10; i++) {
        printf("%d,",ordereps[i]);
    }
    printf("\n");
    NSLog(@"=====================");
    
//    [[ZZDownloadManager shared] startEpTaskWithEpId:@"123"];
//    [[ZZDownloadManager shared] startEpTaskWithEpId:@"124"];
//    [[ZZDownloadManager shared] startEpTaskWithEpId:@"125"];
//    [[ZZDownloadManager shared] startEpTaskWithEpId:@"126"];
//    [[ZZDownloadManager shared] startEpTaskWithEpId:@"127"];
//    
//    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"123"];
//    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"124"];
//    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"125"];
//    [[ZZDownloadManager shared] removeEpTaskWithEpId:@"126"];
//    [[ZZDownloadManager shared] pauseEpTaskWithEpId:@"104"];
//    [[ZZDownloadManager shared] startEpTaskWithEpId:@"104"];
//    [[ZZDownloadManager shared] pauseEpTaskWithEpId:@"104"];
//    [[ZZDownloadManager shared] startEpTaskWithEpId:@"104"];

 
    
//    NSOperationQueue *q = [ZZDownloadNotifyQueue shared];
}

+ (void)xxx:(NSNotification *)notification
{
    NSDictionary *dict = notification.object;
    ZZDownloadTask *task = dict[@"task"];
    ZZDownloadBaseEntity *entity = dict[@"entity"];
    
//    NSLog(@"=-=-=-=");
//    NSLog(@"key=%@, state=%lu", [entity entityKey], task.state);
//    NSLog(@"=-=-=-=");
}

@end
