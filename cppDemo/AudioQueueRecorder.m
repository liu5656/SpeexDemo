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

#define MaxBufferSize 8192

#define kAQAudioSampleRate 16000
#define kAQBitsPerChannel 16
#define kAQChannelsPerFrame 1
#define kAQFramesPerPacket 1

@interface AudioQueueRecorder()
{
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef               mQueue;
    AudioQueueBufferRef         mBuffers[3];
    AudioFileID                 mAudioFile;
}
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) NSMutableData *audioData;
@end

@implementation AudioQueueRecorder

- (instancetype)initWithSampleRate:(Float64)sampleRate andChannelsPerFrame:(UInt32)channels andBitsPerChannel:(UInt32)bits {
    if (self = [super init]) {
        [self setRecordFormatWithFormatID:kAudioFormatLinearPCM];
        [self createAudioInput];
    }
    return self;
}

- (void)setRecordFormatWithFormatID:(UInt32)formatID {
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

void AQInputCallback(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumberPacketDescriptions, const AudioStreamPacketDescription * __nullable inPacketDescs){
    AudioQueueRecorder *recorder = (__bridge AudioQueueRecorder*)inUserData;
    if (inNumberPacketDescriptions > 0) {
        NSLog(@"inbuffer.size:%d", inBuffer->mAudioDataByteSize);
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
    
    OSStatus status = AudioQueueNewInput(&mDataFormat, AQInputCallback, (__bridge void *)self, NULL, kCFRunLoopCommonModes, 0, &mQueue);
    if (status != noErr) {
        NSLog(@"initialize audio queue failed:%d", status);
        return;
    }
//    status = AudioQueueAddPropertyListener(state.mQueue, kAudioQueueProperty_IsRunning, AQInputCallback, (__bridge void*)self);
//    if (status != noErr) {
//        NSLog(@"observer property failed");
//        return;
//    }
    UInt32 bufferSize = 0;
    DeriveBufferSize(mQueue, &mDataFormat, 0.5, &bufferSize);
    
    for (int i = 0; i < 3; ++i) {
        AudioQueueAllocateBuffer(mQueue, bufferSize, &mBuffers[i]);
        AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
//    CFURLRef audioFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("output.caf"), kCFURLPOSIXPathStyle, false);
//    AudioFileID mAudioFile;
//    AudioFileCreateWithURL(audioFileURL, kAudioFileAIFFType, &_aqState.mDataFormat, kAudioFileFlags_EraseFile, &_aqState.mAudioFile);
}

void DeriveBufferSize (AudioQueueRef audioQueue,AudioStreamBasicDescription *ASBDescription, Float64 seconds,UInt32                       *outBufferSize) {
    static const int maxBufferSize = 0x50000;
    
    int maxPacketSize = (*ASBDescription).mBytesPerPacket;
    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty(audioQueue,kAudioQueueProperty_MaximumOutputPacketSize,&maxPacketSize,&maxVBRPacketSize);
    }
    
    Float64 numBytesForTime = (*ASBDescription).mSampleRate * maxPacketSize * seconds;
    *outBufferSize = numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize;
}


- (void)pause {
    OSStatus status = AudioQueuePause(mQueue);
    if (status == noErr) {
        _isRecording = NO;
    }
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/audio"];
    BOOL result = [_audioData writeToFile:path atomically:YES];
    NSLog(@"");
}

- (void)record {
    if (mQueue) {
        _isRecording = YES;
        AudioQueueStart(mQueue, NULL);
    }
}

- (NSMutableData *)audioData {
    if (!_audioData) {
        _audioData = [NSMutableData data];
    }
    return _audioData;
}




@end
