//
//  ZZDownloadMessage.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadMessage.h"

@implementation ZZDownloadMessage

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{};
}

+ (NSValueTransformer *)taskClassJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return NSClassFromString(str);
    } reverseBlock:^(Class x) {
        return NSStringFromClass(x);
    }];
}

@end
