//
//  AudioUnitRecorder2.m
//  cppDemo
//
//  Created by lj on 2017/12/18.
//  Copyright © 2017年 lj. All rights reserved.
//

/*
    边录边播放,耳机或者外放
 */

#import "AudioUnitPlayAndRecord.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0

@implementation AudioUnitPlayAndRecord
{
    AudioUnit           audioUnit;
    AudioBufferList     bufferList;
    NSInputStream       *inputStream;
}

- (instancetype)init {
    if (self = [super init]) {
        [self initialRecord];
    }
    return self;
}

- (void)playAndRecord {
    AudioOutputUnitStart(audioUnit);
}

- (void)stop {
    AudioOutputUnitStop(audioUnit);
}

- (void)initialRecord {
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"originalpcm" withExtension:nil];
    inputStream = [NSInputStream inputStreamWithURL:url];
    if (!inputStream) {
        NSLog(@"打开文件失败:%@", url);
    }else{
        [inputStream open];
    }
    
    NSError *error =nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.05 error:&error];
//    [session setActive:YES error:&error];
    
    AudioComponentDescription           desc;
    desc.componentType                  = kAudioUnitType_Output;
    desc.componentSubType               = kAudioUnitSubType_VoiceProcessingIO;
    desc.componentFlags                 = 0;
    desc.componentFlagsMask             = 0;
    desc.componentManufacturer          = kAudioUnitManufacturer_Apple;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    OSStatus status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    checkStatus2(status, "get audio units fialed");
    
    // Enable IO for recording
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  INPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    checkStatus2(status, "Enable IO for recording failed");
    
    // Describe format
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate             = 16000;
    audioFormat.mFormatID               = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags            = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket        = 1;
    audioFormat.mChannelsPerFrame       = 1;
    audioFormat.mBitsPerChannel         = 16;
    audioFormat.mBytesPerPacket         = 2;
    audioFormat.mBytesPerFrame          = 2;
    
    // Apply format for recording
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  INPUT_BUS,
                                  &audioFormat,
                                  sizeof(audioFormat));
    checkStatus2(status, "Apply format failed for recording");
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &audioFormat,
                                  sizeof(audioFormat));
    checkStatus2(status, "Apply format failed for playback");
    
    // Set input callback
    AURenderCallbackStruct          callbackStruct;
    callbackStruct.inputProc        = recordingCallback;
    callbackStruct.inputProcRefCon  = (__bridge void *)(self);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  INPUT_BUS,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus2(status, "Set input callback failed");
    
    callbackStruct.inputProc        = playbackCallback;
    callbackStruct.inputProcRefCon  = (__bridge void *)(self);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  OUTPUT_BUS,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus2(status, "Set output callback failed");
    
    // Initialise
    status = AudioUnitInitialize(audioUnit);
    checkStatus2(status, "Disable buffer allocation for the recorder failed");
    
    
}

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {

    AudioUnitPlayAndRecord *recorder = (__bridge AudioUnitPlayAndRecord*)inRefCon;
    recorder->bufferList.mNumberBuffers = 1;
    recorder->bufferList.mBuffers[0].mData = NULL;
    recorder->bufferList.mBuffers[0].mDataByteSize = 0;
    AudioUnitRender(recorder->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &recorder->bufferList);
    return noErr;
}

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    AudioUnitPlayAndRecord *recorder = (__bridge AudioUnitPlayAndRecord*)inRefCon;
    ioData->mBuffers[0].mData = recorder->bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = recorder->bufferList.mBuffers[0].mDataByteSize;
    ioData->mBuffers[0].mNumberChannels = recorder->bufferList.mBuffers[0].mNumberChannels;
    ioData->mNumberBuffers = 1;
    return noErr;
}


void checkStatus2(OSStatus status, char error[]) {
    if (status != noErr) {
        printf("error:%d--%s", status, error);
        exit(-1);
    }
}


@end
