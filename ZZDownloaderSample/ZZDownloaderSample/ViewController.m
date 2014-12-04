//
//  ViewController.m
//  ZZDownloaderSample
//
//  Created by zhangxinzheng on 11/13/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#import "ViewController.h"
#import "ZZDownloader.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [ZZDownloader dosth];
    
//    UIViewController *x1 = [UIViewController new];
//    x1.view.backgroundColor = [UIColor redColor];
//    UIView * x = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, 400)];
//    [x setBackgroundColor:[UIColor greenColor]];
//    [x1.view addSubview:x];
//    
//    UIViewController *x2 = [UIViewController new];
//    x2.view.backgroundColor = [UIColor blueColor];
//    
//    UINavigationController *n1 = [[UINavigationController alloc]initWithRootViewController:x1];
//    UINavigationController *n2 = [[UINavigationController alloc]initWithRootViewController:x2];
//    
//    self.viewControllers = @[n1,n2];
//    UIButton *b = [UIButton new];
//    [b setFrame:CGRectMake(10, 10, 40, 20)];
//    [b setBackgroundColor:[UIColor purpleColor]];
//    [b addTarget:self action:@selector(abc) forControlEvents:UIControlEventTouchUpInside];
//    [self.tabBar addSubview:b];
}

//- (void)abc
//{
//    UIViewController *p = [UIViewController new];
//    p.view.backgroundColor = [UIColor yellowColor];
//    UINavigationController *x = self.selectedViewController;
//    [x pushViewController:p animated:YES];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
