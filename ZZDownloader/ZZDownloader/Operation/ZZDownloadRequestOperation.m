//
//  ZZDownloadRequestOperation.m
//  Pods
//
//  Created by zhangxinzheng on 11/18/14.
//
//

#import "ZZDownloadRequestOperation.h"

@interface ZZDownloadRequestOperation ()

@property (nonatomic) BOOL _paused;

@end

@implementation ZZDownloadRequestOperation

- (void)pause
{
    self._paused = YES;
    [super pause];
}

- (void)resume
{
    self._paused = NO;
    [super resume];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (self._paused) {
        NSLog(@"I pausedlalala");
        return;
    }
    [super connection:connection didReceiveData:data];
}
@end
