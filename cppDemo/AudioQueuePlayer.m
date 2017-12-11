//
//  AudioQueuePlayer.m
//  cppDemo
//
//  Created by lj on 2017/12/8.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "AudioQueuePlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define MaxBufferSize 8192

static const int kNumberBuffers = 3;                              // 1
typedef struct AQPlayerState {
    AudioStreamBasicDescription   mDataFormat;                    // 2
    AudioQueueRef                 mQueue;                         // 3
    AudioQueueBufferRef           mBuffers[kNumberBuffers];       // 4
    AudioFileID                   mAudioFile;                     // 5
    UInt32                        bufferByteSize;                 // 6
    SInt64                        mCurrentPacket;                 // 7
    UInt32                        mNumPacketsToRead;              // 8
    AudioStreamPacketDescription  *mPacketDescs;                  // 9
    bool                          mIsRunning;                     // 10
} AQPlayerState;

@interface AudioQueuePlayer(){
    int mBuffersUsed[3];
}


@property (nonatomic, assign) AQPlayerState aqState;
@property (nonatomic, strong) NSLock *sysnLock;
@property (nonatomic, strong) NSArray *bufferUsed;              //判断音频缓存是否在使用

@end

@implementation AudioQueuePlayer

- (instancetype)initWithSampleRate:(Float64)sampleRate andChannelsPerFrame:(UInt32)channels andBitsPerChannel:(UInt32)bits {
    if (self = [super init]) {
        _aqState.mDataFormat.mFormatID = kAudioFormatLinearPCM;
        _aqState.mDataFormat.mSampleRate = sampleRate;
        _aqState.mDataFormat.mChannelsPerFrame = channels;
        _aqState.mDataFormat.mBitsPerChannel = bits;
        _aqState.mDataFormat.mBytesPerFrame = _aqState.mDataFormat.mChannelsPerFrame * sizeof (SInt16);
        _aqState.mDataFormat.mBytesPerPacket = _aqState.mDataFormat.mBytesPerFrame;
        _aqState.mDataFormat.mFramesPerPacket = 1;
        _aqState.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        _sysnLock = [[NSLock alloc] init];
        [self createAudioOutput];
        
        
    }
    return self;
}

void AQOutputCallback(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    
    AudioQueuePlayer *player = (__bridge AudioQueuePlayer *)inUserData;
    [player resetBufferState:inBuffer andAudioQueue:inAQ];
}

- (void)resetBufferState:(AudioQueueBufferRef)inBuffer andAudioQueue:(AudioQueueRef)inAQ {
    for (int i = 0; i < kNumberBuffers; i++) {
        if(inBuffer == self.aqState.mBuffers[i]){
            mBuffersUsed[i] = 0;
            NSLog(@"player call back----%d----%@", mBuffersUsed[i], [NSThread currentThread]);
            break;
        }
    }
}

- (void)createAudioOutput {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryMultiRoute error:&error];
    if (error) {
        NSLog(@"setup audio category failed:%@", error);
        return;
    }
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"turn on sesstion failed:%@", error);
        return;
    }
    
    OSStatus status = AudioQueueNewOutput(&_aqState.mDataFormat, AQOutputCallback, (__bridge void*)self, nil, 0, 0, &_aqState.mQueue);
    if (status != noErr) {
        NSLog(@"inital audio queue output failed:%d", status);
        return;
    }
    //    status = AudioQueueAddPropertyListener(state.mQueue, kAudioQueueProperty_IsRunning, AQInputCallback, (__bridge void*)self);
    //    if (status != noErr) {
    //        NSLog(@"observer property failed");
    //        return;
    //    }
    for (int i = 0; i < kNumberBuffers; i++) {
        AudioQueueAllocateBuffer(_aqState.mQueue, MaxBufferSize, &_aqState.mBuffers[i]);
        AudioQueueEnqueueBuffer(_aqState.mQueue, _aqState.mBuffers[i], 0, NULL);
    }
    
//    AudioQueueSetParameter(_aqState.mQueue, kAudioQueueParam_Volume, 1.0);
    
    status = AudioQueueStart(_aqState.mQueue, NULL);
    if (status != noErr) {
        NSLog(@"audio queue start error");
        return;
    }
}

- (void)pause {
    
}

- (void)playWithData:(Byte *)buffer andSize:(UInt32)length {
    [_sysnLock lock];
    if (length > 0) {
        int i = 0;
        while (true) {
            NSLog(@"play-----%@", [NSThread currentThread]);
            if (!mBuffersUsed[i]) {
                mBuffersUsed[i] = 1;
                break;
            }
            i++;
            if (i >= kNumberBuffers) i = 0;
        }

        memcpy(_aqState.mBuffers[i] -> mAudioData, buffer, length);
        _aqState.mBuffers[i]->mAudioDataByteSize = length;
        OSStatus status = AudioQueueEnqueueBuffer(_aqState.mQueue, _aqState.mBuffers[i], 0, NULL);
        NSLog(@"status:%d--%d", status, length);
        
    }
    [_sysnLock unlock];
}

@end
