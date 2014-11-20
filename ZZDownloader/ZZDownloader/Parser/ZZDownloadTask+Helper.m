//
//  ZZDownloadTaskHelper.m
//  Pods
//
//  Created by zhangxinzheng on 11/17/14.
//
//

#import "ZZDownloadTask+Helper.h"

@implementation ZZDownloadTask (Helper)

- (ZZDownloadBaseEntity *)recoverEntity
{
    NSString *type = self.entityType;
    if ([ZZDownloadValidEntity containsObject:type]) {
        Class class = NSClassFromString(type);
        ZZDownloadBaseEntity *entity = [[class alloc] init];
        [entity setValuesForKeysWithDictionary:self.argv];
        return entity;
    }
    return nil;
}

@end
