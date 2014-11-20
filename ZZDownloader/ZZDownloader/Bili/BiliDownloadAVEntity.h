//
//  BiliDownloadAVEntity.h
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "ZZDownloadBaseEntity.h"

@interface BiliDownloadAVEntity : ZZDownloadBaseEntity 

@property (nonatomic) NSString *av_id;
@property (nonatomic) int32_t page;

@property (nonatomic) NSString *cid;
@property (nonatomic) NSString *from;
@property (nonatomic) NSString *type_tag;

@end
