//
//  ZZdownloadTaskOperationHeader.h
//  ZZDownloader
//
//  Created by zhangxinzheng on 12/19/14.
//  Copyright (c) 2014 zhangxinzheng. All rights reserved.
//

#ifndef ibiliplayer_ZZdownloadTaskOperationHeader_h
#define ibiliplayer_ZZdownloadTaskOperationHeader_h

@protocol ZZDownloadTaskOperationDelegate <NSObject>

- (void)updateTaskWithBlock:(void (^)())block;

- (void)notifyUpdate:(NSString *)key;

@end

typedef NS_ENUM(NSInteger, ZZTaskOperationState)
{
    ZZTaskOperationStatePaused = -1,
    ZZTaskOperationStateReady = 1,
    ZZTaskOperationStateExecuting = 2,
    ZZTaskOperationStateFinish = 3
};


static inline NSString * ZZKeyPathFromOperationState(ZZTaskOperationState state)
{
    switch (state) {
        case ZZTaskOperationStateReady:
            return @"isReady";
        case ZZTaskOperationStateExecuting:
            return @"isExecuting";
        case ZZTaskOperationStateFinish:
            return @"isFinished";
        case ZZTaskOperationStatePaused:
            return @"isPaused";
        default: {
            return @"state";
        }
    }
}

static inline BOOL ZZStateTransitionIsValid(ZZTaskOperationState fromState, ZZTaskOperationState toState, BOOL isCancelled)
{
    switch (fromState) {
        case ZZTaskOperationStateReady:
            switch (toState) {
                case ZZTaskOperationStatePaused:
                case ZZTaskOperationStateExecuting:
                    return YES;
                case ZZTaskOperationStateFinish:
                    return isCancelled;
                default:
                    return NO;
            }
        case ZZTaskOperationStateExecuting:
            switch (toState) {
                case ZZTaskOperationStatePaused:
                case ZZTaskOperationStateFinish:
                    return YES;
                default:
                    return NO;
            }
        case ZZTaskOperationStateFinish:
            switch (toState) {
                case ZZTaskOperationStateFinish:
                    return NO;
                default:
                    return YES;
            }
            return NO;
        case ZZTaskOperationStatePaused:
            return toState == ZZTaskOperationStateReady;
        default: {
            switch (toState) {
                case ZZTaskOperationStatePaused:
                case ZZTaskOperationStateReady:
                case ZZTaskOperationStateExecuting:
                case ZZTaskOperationStateFinish:
                    return YES;
                default:
                    return NO;
            }
        }
    }
}
#endif
