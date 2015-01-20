//
//  SampleEntity.m
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

- (BOOL)updateSelf
{
    // do sth to update self
    return YES;
}

- (NSString *)uniqueKey
{
    return self.cid;
}

- (BOOL)isValid:(ZZDownloadTask *)task
{
    // do sth to check self is valid
    return YES;
}

- (NSString *)destinationDirPath
{
    return [NSString stringWithFormat:@"cid_%@", self.cid];
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
    NSString *query = [NSString stringWithFormat:@"http://api.tv.sohu.com/v4/video/info/%@.json?aid=%@&site=0&api_key=9854b2afa779e1a6bff1962447a09dbd&plat=6&sver=4.0.2&partner=2",self.cid, self.cid];
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
    NSDictionary *dict = j[@"data"];
    if ([dict isKindOfClass:[NSDictionary class]]) {
        NSString *s1 = dict[@"download_url"];
        if ([s1 isKindOfClass:[NSString class]] && s1.length) {
            return s1;
        }
    }
    return @"";
}

- (NSUInteger)getSectionTotalLengthWithCount:(NSInteger)index
{
    return 0;
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
