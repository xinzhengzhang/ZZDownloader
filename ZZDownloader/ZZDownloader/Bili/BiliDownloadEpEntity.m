//
//  BiliDownloadEpEntity.m
//  Pods
//
//  Created by zhangxinzheng on 11/14/14.
//
//

#import "BiliDownloadEpEntity.h"

@implementation BiliDownloadEpEntity

- (NSString *)entityType
{
    return @"BiliDownloadEpEntity";
}

- (NSString *)entityKey
{
    return [NSString stringWithFormat:@"ep_%@", self.ep_id];
}

- (NSString *)destinationDirPath
{
//    return @"bangumi1/ep123/youku/high";
    return [NSString stringWithFormat:@"bangumi/ep%@/youku/high", self.ep_id];
}

- (NSString *)destinationRootDirPath
{
    return [NSString stringWithFormat:@"bangumi/ep%@", self.ep_id];
}

- (NSString *)getSectionUrlWithCount:(NSInteger)index
{
    return @"http://v.iask.com/v_play_ipad.php?vid=93146987";
    if (index == 2) {
        return @"http://10.240.131.227:8000/Leanpub.Functional%20Reactive%20Programming%20on%20iOS.2014.pdf";
    }
    if (index == 1) {
        return @"http://10.240.131.227:8000/FunctionalReactivePixels-master.zip";
    }
    if (index == 0) {
        return @"http://10.240.131.227:8000/FauxPas-1.2.zip";
    }
    return @"";
}


- (NSString *)danmakuPath
{
    return @"";
}

- (int32_t)getSectionCount
{
    return 1;
}

@end
