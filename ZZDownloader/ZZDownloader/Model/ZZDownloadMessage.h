//
//  ZZDownloadMessage.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Mantle/Mantle.h>

typedef NS_ENUM(NSUInteger, ZZDownloadMessageCommand) {
    ZZDownloadMessageCommandNeedUpdateInfo = 1034,
    ZZDownloadMessageCommandNeedNotifyUI,
    ZZDownloadMessageCommandNeedBuild
};

@interface ZZDownloadMessage : MTLModel <MTLJSONSerializing>

@property (nonatomic) ZZDownloadMessageCommand command;
@property (nonatomic) Class<MTLJSONSerializing> taskClass;
@property (nonatomic, strong) NSString *tId;
@property (nonatomic, strong) NSString *key;

@end
