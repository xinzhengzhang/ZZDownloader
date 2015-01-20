//
//  ZZOperation.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

typedef NS_ENUM(NSUInteger, ZZDownloadCommand) {
    ZZDownloadCommandStart = 1001,
    ZZDownloadCommandStop,
    ZZDownloadCommandInterruptStop,
    ZZDownloadCommandRemove,
    ZZDownloadCommandCheck,
    ZZDownloadCommandBuild,
    ZZDownloadCommandResumeAll,
    ZZDownloadCommandPauseAll,
    ZZDownloadCommandCheckAllGroup,
    ZZDownloadCommandCheckGroup,
    ZZDownloadCommandStartCache
};

@interface ZZDownloadOperation : NSObject

@property (nonatomic) ZZDownloadCommand command;
@property (nonatomic, strong) NSString *key;

@end
