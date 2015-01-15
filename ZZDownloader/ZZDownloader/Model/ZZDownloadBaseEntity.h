//
//  ZZDownloadBaseEntity.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "ZZDownloadParserProtocol.h"

@interface ZZDownloadBaseEntity : MTLModel <MTLJSONSerializing, ZZDownloadParserProtocol>

@property (nonatomic) int32_t sections;
+ (NSArray *)argvKeys;
+ (const void  **)argvKeysFlags;


@end
