//
//  BiliDownloadAVEntity.h
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "ZZDownloadBaseEntity.h"

@class BiliVideo;

@interface BiliDownloadAVEntity : ZZDownloadBaseEntity 

@property (nonatomic) NSString *av_id;
@property (nonatomic) int32_t page;

+ (NSString *)getEntityKeyWithAvid:(NSString *)av_id page:(int32_t)page;

@property (nonatomic) NSString *from;
@property (nonatomic) NSString *cid;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *coverUrl;

@property (nonatomic) NSString *avname;
@end
