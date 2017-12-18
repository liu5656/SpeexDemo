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

#define kAQAudioSampleRate 16000
#define kAQBitsPerChannel 16
#define kAQChannelsPerFrame 1
#define kAQFramesPerPacket 1

static const int kNumberBuffers = 3;

@interface AudioQueuePlayer(){
    AudioStreamBasicDescription   mDataFormat;
    AudioQueueRef                 mQueue;
    AudioQueueBufferRef           mBuffers[kNumberBuffers];
}
@end

@implementation AudioQueuePlayer

- (instancetype)init {
    if (self = [super init]) {
        [self setPlayFormatWithFormatID:kAudioFormatLinearPCM];
        [self createAudioOutput];
    }
    return self;
}

void AQOutputCallback(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    //    AudioQueuePlayer *player = (__bridge AudioQueuePlayer *)inUserData;
    //    [player resetBufferState:inBuffer andAudioQueue:inAQ];
}

- (void)resetBufferState:(AudioQueueBufferRef)inBuffer andAudioQueue:(AudioQueueRef)inAQ {
    //    for (int i = 0; i < kNumberBuffers; i++) {
    //        if(inBuffer == mBuffers[i]){
    //            mBuffersUsed[i] = 0;
    ////            NSLog(@"player call back----%d----%@", mBuffersUsed[i], [NSThread currentThread]);
    //            break;
    //        }
    //    }
}

- (void)setPlayFormatWithFormatID:(UInt32)formatID {
    memset(&mDataFormat, 0, sizeof(mDataFormat));
    mDataFormat.mSampleRate = kAQAudioSampleRate; // 设置采样率
    mDataFormat.mChannelsPerFrame = kAQChannelsPerFrame;
    mDataFormat.mFormatID = formatID;
    if (formatID == kAudioFormatLinearPCM) {
        mDataFormat.mFormatFlags     = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        mDataFormat.mBitsPerChannel  = kAQBitsPerChannel;
        mDataFormat.mBytesPerFrame   = (mDataFormat.mBitsPerChannel / 8) * mDataFormat.mChannelsPerFrame;
        mDataFormat.mFramesPerPacket = kAQFramesPerPacket;
        mDataFormat.mBytesPerPacket  = mDataFormat.mBytesPerFrame;
    }
}

- (void)setupSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"setup audio category failed:%@", error);
        return;
    }
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"turn on sesstion failed:%@", error);
        return;
    }
//    for (NSString *input in session.availableModes) {
//        NSLog(@"input:%@", input);
//    }
    
    //    [session setPreferredInput:<#(nullable AVAudioSessionPortDescription *)#> error:<#(NSError * _Nullable __autoreleasing * _Nullable)#>]
    
    // 临时改变当前音频文件播放方式
    //    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    //    if (error) {
    //        NSLog(@"temporarily changes the current audio route failed:%@", error);
    //    }
    
}

- (void)createAudioOutput {
    [self setupSession];
    OSStatus status = AudioQueueNewOutput(&mDataFormat, AQOutputCallback, (__bridge void*)self, nil, 0, 0, &mQueue);
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
        AudioQueueAllocateBuffer(mQueue, MaxBufferSize, &mBuffers[i]);
        AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
    AudioQueueSetParameter(mQueue, kAudioQueueParam_Volume, 1.0);
    
    status = AudioQueueStart(mQueue, NULL);
    if (status != noErr) {
        NSLog(@"audio queue start error");
        return;
    }
}

- (void)pause {
    
}

static int i = 0;
- (void)playWithData:(Byte *)buffer andSize:(UInt32)length {
    if (length > 0) {
        mBuffers[i]->mAudioDataByteSize = length;
        memset(mBuffers[i]->mAudioData, 0, length);
        memcpy(mBuffers[i] -> mAudioData, buffer, length);
        AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
        i++;
        if (3 == i) i = 0;
    }
}












@end

