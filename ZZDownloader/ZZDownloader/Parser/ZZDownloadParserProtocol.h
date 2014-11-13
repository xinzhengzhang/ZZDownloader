//
//  ZZDownloadParserProtocol.h
//  Pods
//
//  Created by zhangxinzheng on 11/13/14.
//
//

#import <Foundation/Foundation.h>

@protocol ZZDownloadParserProtocol <NSObject>

@required
- (NSString *)destinationPath;
- (NSArray *)sections;

@end
