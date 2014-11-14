//
//  ZZOperation.m
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import "ZZDownloadOperation.h"

@implementation ZZDownloadOperation
+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{};
}

//+ (NSValueTransformer *)taskClassJSONTransformer
//{
//    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
//        return NSClassFromString(str);
//    } reverseBlock:^(Class x) {
//        return NSStringFromClass(x);
//    }];
//}

@end
