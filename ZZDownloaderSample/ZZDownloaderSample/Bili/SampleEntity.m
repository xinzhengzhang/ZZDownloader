//
//  BiliDownloadAVEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "SampleEntity.h"
#import "ZZDownloadTaskManagerV2.h"
#import <objc/runtime.h>
@implementation SampleEntity

static NSMutableDictionary *cacheVideoSourceDict;
static NSRecursiveLock *cacheLock;

+ (const void  **)argvKeysFlags
{
    static const char cid_f;
    static const void* address[1] = {&cid_f};
    return address;
}

+ (NSArray *)argvKeys
{
    return @[@"cid"];
}


- (NSString *)entityType
{
    return @"SampleEntity";
}

- (NSString *)entityKey
{
    return [NSString stringWithFormat:@"cid_%@", self.cid];
}

- (NSString *)realKey
{
    return [NSString stringWithFormat:@"%@",self.cid];
}

- (NSString *)aggregationKey
{
    NSAssert(self.cid, @"aggregationKeyError");
    return [NSString stringWithFormat:@"cid_%@", self.cid];
}

- (NSString *)aggregationType
{
    return @"SampleGroup";
}

- (NSString *)aggregationTitle
{
    return self.cid;
}

- (NSString *)title
{
    return self.cid;
}

- (void)downloadCoverWithDownloadStartBlock:(void (^)(void))block
{
    return;
}

- (NSString *)getCoverPath
{
    return @"";
}

- (BOOL)updateSelf
{
    return YES;
}

- (NSString *)uniqueKey
{
    return self.cid;
}

- (BOOL)isValid:(ZZDownloadTask *)task
{
    return YES;
}

- (NSString *)destinationDirPath
{
    return [NSString stringWithFormat:@"cid_%@", self.cid];
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
    NSString *query = [NSString stringWithFormat:@"http://interface.bilibili.com/playurl?platform=android&cid=%@&quality=1&otype=json&appkey=c1b107428d337928",self.cid];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:query]];
    NSError *error;
    NSData *response = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
    if (error) {
        return @"";
    }
    NSDictionary *j = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        return @"";
    }
    NSArray *arr = j[@"durl"];
    if ([arr isKindOfClass:[NSArray class]] && arr.count) {
        NSDictionary *s1 = arr[0];
        if ([s1 isKindOfClass:[NSDictionary class]] && [s1[@"url"] length]) {
            return s1[@"url"];
        }
    }
    return @"";
}

- (NSUInteger)getSectionTotalLengthWithCount:(NSInteger)index
{
    return 0;
}

- (void)downloadDanmakuWithDownloadStartBlock:(void (^)(void))block
{
}

- (NSString *)getDanmakuPath
{
    return [[ZZDownloadTaskManagerV2 downloadFolder] stringByAppendingPathComponent:[[self destinationDirPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.danmaku", self.entityKey]]];
}


- (NSString *)destinationRootDirPath
{
    return [NSString stringWithFormat:@"cid_%@", self.cid];
}

- (int32_t)getSectionCount
{
    return 1;
}

@end
