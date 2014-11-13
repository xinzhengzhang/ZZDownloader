//
//  ZZTask.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
#import "ZZDownloadParserProtocol.h"

typedef NS_ENUM(NSUInteger, ZZDownloadState) {
    ZZDownloadStateWaiting = 1234,
    ZZDownloadStateDownloading,
    ZZDownloadStateShouldPause,
    ZZDownloadStateShouldRemove,
    ZZDownloadStatePaused,
    ZZDownloadStateDownloaded,
    ZZDownloadStateFail,
    ZZDownloadStateInvalid
};

// MARK: subClass has to implement ZZDownloadParserProtocol
@interface ZZDownloadTask : MTLModel <MTLJSONSerializing, ZZDownloadParserProtocol>

@property (nonatomic) ZZDownloadState state;
@property (nonatomic) float progress;
@property (nonatomic) int32_t triedCount;

@property (nonatomic, strong) NSDictionary *params;

@end
