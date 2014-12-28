//
//  ZZDownloadParserProtocol.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>
#import "ZZDownloadTask.h"
typedef NS_ENUM(NSUInteger, ZZDownloadEntityType) {
    ZZDownloadEntityTypeNormal = 2333,
    ZZDownloadEntityTypePPTV
};

@class ZZDownloadTask;

@protocol ZZDownloadParserProtocol <NSObject>

@required
- (NSString *)entityType;
- (NSString *)entityKey;
- (NSString *)aggregationKey;
- (NSString *)realKey;
- (NSString *)aggregationType;
- (NSString *)title;
- (NSString *)aggregationTitle;
- (NSString *)uniqueKey;
- (BOOL)updateSelf;
- (BOOL)isValid:(ZZDownloadTask *)task;
- (NSString *)destinationDirPath;
- (NSString *)destinationRootDirPath;
- (int32_t)getSectionCount;
- (NSString *)getSectionUrlWithCount:(NSInteger)index;
- (NSUInteger)getSectionTotalLengthWithCount:(NSInteger)index;
- (NSString *)getDanmakuPath;
- (NSString *)getCoverPath;
- (void)downloadDanmakuWithDownloadStartBlock:(void (^)(void))block;
- (void)downloadCoverWithDownloadStartBlock:(void (^)(void))block;

@end
