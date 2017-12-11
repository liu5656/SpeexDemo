//
//  AudioQueueRecorder.m
//  cppDemo
//
//  Created by lj on 2017/12/8.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "AudioQueueRecorder.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

typedef struct AQRecorderState {
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef               mQueue;
    AudioQueueBufferRef         mBuffers[3];
} AQRecorderState;

#define MaxBufferSize 8192

@interface AudioQueueRecorder()
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic,assign) AQRecorderState aqState;
@property (nonatomic, strong) NSMutableData *audioData;
@end

@implementation AudioQueueRecorder

- (instancetype)initWithSampleRate:(Float64)sampleRate andChannelsPerFrame:(UInt32)channels andBitsPerChannel:(UInt32)bits {
    if (self = [super init]) {
        _aqState.mDataFormat.mFormatID = kAudioFormatLinearPCM;
        _aqState.mDataFormat.mSampleRate = sampleRate;
        _aqState.mDataFormat.mChannelsPerFrame = channels;
        _aqState.mDataFormat.mBitsPerChannel = bits;
//        _aqState.mDataFormat.mBytesPerFrame = _aqState.mDataFormat.mChannelsPerFrame * (_aqState.mDataFormat.mBitsPerChannel / 8);
        
        _aqState.mDataFormat.mFramesPerPacket = 1;
//        _aqState.mDataFormat.mBytesPerPacket = _aqState.mDataFormat.mBytesPerFrame * _aqState.mDataFormat.mFramesPerPacket;
        _aqState.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        [self createAudioInput];
    }
    return self;
}


void AQInputCallback(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumberPacketDescriptions, const AudioStreamPacketDescription * __nullable inPacketDescs){
    AudioQueueRecorder *recorder = (__bridge AudioQueueRecorder*)inUserData;
    if (inNumberPacketDescriptions > 0) {
        NSLog(@"inbuffer.size:%d", inBuffer->mAudioDataByteSize);
//        if (recorder.audioData.length < MaxBufferSize) {
//            
//        }
        [recorder.player playWithData:inBuffer->mAudioData andSize:inBuffer->mAudioDataByteSize];
    }
    if (recorder.isRecording) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}

- (void)createAudioInput {
    NSError *nsError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryMultiRoute error:&nsError];
    [session setActive:YES error:&nsError];
    
    OSStatus status = AudioQueueNewInput(&_aqState.mDataFormat, AQInputCallback, (__bridge void *)self, NULL, kCFRunLoopCommonModes, 0, &_aqState.mQueue);
    if (status != noErr) {
        NSLog(@"initialize audio queue failed:%d", status);
        return;
    }
//    status = AudioQueueAddPropertyListener(state.mQueue, kAudioQueueProperty_IsRunning, AQInputCallback, (__bridge void*)self);
//    if (status != noErr) {
//        NSLog(@"observer property failed");
//        return;
//    }
    for (int i = 0; i < 3; ++i) {
        AudioQueueAllocateBuffer(_aqState.mQueue, MaxBufferSize, &_aqState.mBuffers[i]);
        AudioQueueEnqueueBuffer(_aqState.mQueue, _aqState.mBuffers[i], 0, NULL);
    }
}


- (void)pause {
    OSStatus status = AudioQueuePause(_aqState.mQueue);
    if (status == noErr) {
        _isRecording = NO;
    }
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/audio"];
    BOOL result = [_audioData writeToFile:path atomically:YES];
    NSLog(@"");
}

- (void)record {
    if (_aqState.mQueue) {
        _isRecording = YES;
        AudioQueueStart(_aqState.mQueue, NULL);
    }
}

- (NSMutableData *)audioData {
    if (!_audioData) {
        _audioData = [NSMutableData data];
    }
    return _audioData;
}




@end
