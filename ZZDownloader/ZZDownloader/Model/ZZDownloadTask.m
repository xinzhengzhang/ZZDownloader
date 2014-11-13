//
//  ZZTask.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadTask.h"

@implementation ZZDownloadTask

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{};
}

+ (NSValueTransformer *)paramsJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
    } reverseBlock:^(NSDictionary *x) {
        return [NSString stringWithUTF8String:[[NSJSONSerialization dataWithJSONObject:x options:NSJSONWritingPrettyPrinted error:nil] bytes]];
    }];
}

- (NSString *)destinationPath
{
    NSAssert(nil, @"ZZDownloadTask destinationPath has to be implemantion");
    return @"";
}

- (NSArray *)sections
{
    NSAssert(nil, @"ZZDownloadTask sections has to be implemantion");
    return @[];
}

@end
