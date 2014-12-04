//
//  ZZDownloadRequestOperation.m
//  Pods
//
//  Created by zhangxinzheng on 11/18/14.
//
//

#import "ZZDownloadRequestOperation.h"
#import <CommonCrypto/CommonDigest.h>

@interface ZZDownloadRequestOperation ()

@property (nonatomic) BOOL _paused;
@end

@implementation ZZDownloadRequestOperation

- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath shouldResume:(BOOL)shouldResume forcusContentRange:(BOOL)yesOrNo
{
    if (self = [super initWithRequest:urlRequest targetPath:targetPath shouldResume:shouldResume]) {
        if (yesOrNo) {
            if (!self.request.allHTTPHeaderFields[@"Range"]) {
                NSMutableURLRequest *mutableURLRequest = [self.request mutableCopy];
                NSString *requestRange = [NSString stringWithFormat:@"bytes=%d-", 0];
                [mutableURLRequest setValue:requestRange forHTTPHeaderField:@"Range"];
                [self performSelector:@selector(setRequest:) withObject:mutableURLRequest];
            }
        }
    }
    return self;
}

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

- (NSString *)tempPath {
    NSString *tempPath = nil;
    if (self.targetPath) {
        NSString *rootPath = NSHomeDirectory();
        NSString *subPath = [self.targetPath substringFromIndex:[rootPath length]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        NSString *md5URLString = [[self class] performSelector:@selector(md5StringForString:) withObject:subPath];
        tempPath = [[[self class] performSelector:@selector(cacheFolder)] stringByAppendingPathComponent:md5URLString];
#pragma clang diagnostic pop
    }
    return tempPath;
}

@end
