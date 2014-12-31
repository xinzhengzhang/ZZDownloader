//
//  ZZDownloadBaseEntity.h
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "ZZDownloadParserProtocol.h"

@interface ZZDownloadBaseEntity : MTLModel <MTLJSONSerializing, ZZDownloadParserProtocol>

+ (NSArray *)argvKeys;
+ (const void  **)argvKeysFlags;


@end
