//
//  ZZDownloadRequestOperation.h
//  Pods
//
//  Created by zhangxinzheng on 11/18/14.
//
//

#import "AFDownloadRequestOperation.h"

@interface ZZDownloadRequestOperation : AFDownloadRequestOperation

- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath shouldResume:(BOOL)shouldResume forcusContentRange:(BOOL)yesOrNo;
@property (nonatomic, strong) NSString *key;

@end
