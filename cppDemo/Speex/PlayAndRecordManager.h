//
//  PlayAndRecordManager.h
//  cppDemo
//
//  Created by lj on 2017/12/20.
//  Copyright © 2017年 lj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PlayAndRecordManager : NSObject

+ (instancetype)shared;

- (BOOL)startRecord;
- (BOOL)stopRecord;
- (BOOL)playAudio:(const void *)data andLength:(UInt32)size;
- (BOOL)pausePlay;
- (BOOL)resumePlay;

@end
