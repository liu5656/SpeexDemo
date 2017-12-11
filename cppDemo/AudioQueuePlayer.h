//
//  AudioQueuePlayer.h
//  cppDemo
//
//  Created by lj on 2017/12/8.
//  Copyright © 2017年 lj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioQueuePlayer : NSObject

- (instancetype)initWithSampleRate:(Float64)sampleRate andChannelsPerFrame:(UInt32)channels andBitsPerChannel:(UInt32)bits;
- (void)pause;
- (void)playWithData:(Byte *)buffer andSize:(UInt32)length;

@end
