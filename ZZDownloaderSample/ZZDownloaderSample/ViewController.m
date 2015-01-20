//
//  ViewController.m
//  ZZDownloaderSample
//
//  Created by zhangxinzheng on 11/13/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ViewController.h"
#import "ZZDownloader.h"
#import "ZZDownloadTaskManagerV2.h"
#import "SampleEntity.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"cid2" ofType:@"txt"];

    // start font task
    NSString* fileContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSArray* allLinedStrings = [fileContents componentsSeparatedByCharactersInSet:
     [NSCharacterSet newlineCharacterSet]];
    for (NSString *cid in allLinedStrings) {
        SampleEntity *entity = [SampleEntity new];
        entity.cid = cid;
        
        ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
        operation.command = ZZDownloadCommandStart;
        operation.key = [entity entityKey];
        
        [[ZZDownloadTaskManagerV2 shared] addOp:operation withEntity:entity block:nil];
    }
   
    //ensure all the task assigned by font task was built
    [self performSelector:@selector(startbg) withObject:nil afterDelay:10];

}

- (void)startbg
{

    // start bg task
    [[ZZDownloadTaskManagerV2 shared] checkSelfUnSecheduledWorkKey:nil block:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
