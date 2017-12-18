//
//  AudioQueueRecorder.h
//  cppDemo
//
//  Created by lj on 2017/12/8.
//  Copyright © 2017年 lj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AudioQueuePlayer.h"

@interface AudioQueueRecorder : NSObject
@property (nonatomic, weak) AudioQueuePlayer *player;

- (instancetype)initWithSampleRate:(Float64)sampleRate andChannelsPerFrame:(UInt32)channels andBitsPerChannel:(UInt32)bits;
- (void)pause;
- (void)record;
@end
