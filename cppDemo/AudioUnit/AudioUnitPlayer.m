//
//  AudioUnitPlayer.m
//  cppDemo
//
//  Created by lj on 2017/12/18.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "AudioUnitPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0

#define CONST_BUFFER_SIZE 0x10000

@implementation AudioUnitPlayer
{
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    NSInputStream *inputStream;
}

- (void)play {
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}

- (void)initPlayer {
//    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"originalpcm" withExtension:nil];
    inputStream = [NSInputStream inputStreamWithURL:url];
    if (!inputStream) {
        NSLog(@"打开文件失败:%@", url);
    }else{
        [inputStream open];
    }
    
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
//    bufferList = (AudioBufferList *)malloc((sizeof(AudioBufferList)));
//    bufferList->mNumberBuffers = 1;
//    bufferList->mBuffers->mNumberChannels = 1;
//    bufferList->mBuffers->mDataByteSize = CONST_BUFFER_SIZE;
//    bufferList->mBuffers->mData = malloc(CONST_BUFFER_SIZE);
    
    UInt32 flag = 1;
    OSStatus status = AudioUnitSetProperty(audioUnit,
                                           kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Output,
                                           OUTPUT_BUS,
                                           &flag,
                                           sizeof(flag));
    if (status != noErr) {
        NSLog(@"enableIO failed:%d", status);
        return;
    }
    
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = 16000;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBytesPerFrame = 2;
    outputFormat.mBytesPerPacket = 2;
    outputFormat.mBitsPerChannel = 16;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status != noErr) {
        NSLog(@"set format failed:%d", status);
        return;
    }
    
    AURenderCallbackStruct callback;
    callback.inputProc = PlayCalback;
    callback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &callback, sizeof(callback));
    if (status != noErr) {
        NSLog(@"set callback failed:%d", status);
        return;
    }
    
    status = AudioUnitInitialize(audioUnit);
    if (status != noErr) {
        NSLog(@"initialize audiounit failed:%d", status);
        return;
    }
    
}

OSStatus PlayCalback(void *inRefCon,
                     AudioUnitRenderActionFlags *ioActionFlags,
                    const AudioTimeStamp *inTimeStamp,
                    UInt32 inBusNumber,
                    UInt32 inNumberFrames,
                     AudioBufferList * __nullable    ioData) {
    AudioUnitPlayer *player = (__bridge AudioUnitPlayer *)inRefCon;
    ioData->mBuffers[0].mDataByteSize = (UInt32)[player->inputStream read:ioData->mBuffers[0].mData maxLength:ioData->mBuffers[0].mDataByteSize];
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        NSLog(@"read audio data failed");
        [player stop];
    }
    return noErr;
}


- (void)stop {
    AudioOutputUnitStop(audioUnit);
    if (bufferList) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
    
    [inputStream close];
    
}
























@end
