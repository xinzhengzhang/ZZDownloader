//
//  ZZOperation.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

typedef NS_ENUM(NSUInteger, ZZDownloadCommand) {
    ZZDownloadCommandStart = 1001,
    ZZDownloadCommandStop,
    ZZDownloadCommandResume,
    ZZDownloadCommandRemove,
    ZZDownloadCommandCheck,
    ZZDownloadCommandBuild
};

@interface ZZDownloadOperation : MTLModel <MTLJSONSerializing>

@property (nonatomic) ZZDownloadCommand command;
@property (nonatomic) Class<MTLJSONSerializing> taskClass;
@property (nonatomic, strong) NSString *tId;
@property (nonatomic, strong) NSString *key;

@end
