//
//  AudioQueuePlayer.h
//  cppDemo
//
//  Created by lj on 2017/12/8.
//  Copyright © 2017年 lj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioQueuePlayer : NSObject
- (void)pause;
- (void)playWithData:(Byte *)buffer andSize:(UInt32)length;

@end
