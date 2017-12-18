//
//  AudioUnitRecorder2.h
//  cppDemo
//
//  Created by lj on 2017/12/18.
//  Copyright © 2017年 lj. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AudioUnitRecorder2;

@protocol AudioUnitRecorderDelegate <NSObject>
- (void)AURecorder:(AudioUnitRecorder2 *)recoder andData:(NSData *)data;
@end

@interface AudioUnitRecorder2 : NSObject

- (instancetype)initWithDelegate:(id<AudioUnitRecorderDelegate>)delegate;
- (void)startRecord;
- (void)stopRecord;
@end
