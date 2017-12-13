//
//  AudioUnitRecorder.m
//  cppDemo
//
//  Created by lj on 2017/12/12.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "AudioUnitRecorder.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "AudioQueuePlayer.h"

#define kOutputBus  0
#define kInputBus   1

@interface AudioUnitRecorder(){
    AudioComponentInstance      audioUnit;
    AudioBufferList             *mBufferList;
}

@property (nonatomic, strong) AudioQueuePlayer *player;
@end


@implementation AudioUnitRecorder

- (void)setupSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    if (error) {
        NSLog(@"setup audio category failed:%@", error);
        return;
    }
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"turn on sesstion failed:%@", error);
        return;
    }
}

void checkStatus(OSStatus status, char error[]) {
    if (status != noErr) {
        printf("error:%d--%s", status, error);
        exit(-1);
    }
}

- (instancetype)init{
    if (self = [super init]) {
        [self setupSession];
        
        // Describe audio component
        AudioComponentDescription           desc;
        desc.componentType                  = kAudioUnitType_Output;
//        desc.componentSubType               = kAudioUnitSubType_RemoteIO;
        desc.componentSubType               = kAudioUnitSubType_VoiceProcessingIO;
        desc.componentFlags                 = 0;
        desc.componentFlagsMask             = 0;
        desc.componentManufacturer          = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
        
        // Get audio units
        OSStatus status = AudioComponentInstanceNew(inputComponent, &audioUnit);
        checkStatus(status, "get audio units fialed");
        
        // Enable IO for recording
        UInt32 flag = 1;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      kInputBus,
                                      &flag,
                                      sizeof(flag));
        checkStatus(status, "Enable IO for recording failed");
        
        // Enable IO for playback
        UInt32 zero = 1;// 设置为0 关闭playback
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      kOutputBus,
                                      &zero,
                                      sizeof(zero));
        checkStatus(status, "Enable IO for playback failed");
        
        
        //TODO  声音是8k采样率，16bit，单声道，pcm的
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
                                      kInputBus,
                                      &audioFormat,
                                      sizeof(audioFormat));
        checkStatus(status, "Apply format failed for recording");

        // apply format for playback
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      kOutputBus,
                                      &audioFormat,
                                      sizeof(audioFormat));
        checkStatus(status, "Apply format failed for playback");
        
        
        // Set input callback
        AURenderCallbackStruct          callbackStruct;
        callbackStruct.inputProc        = recordingCallback;
        callbackStruct.inputProcRefCon  = (__bridge void *)(self);
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      kInputBus,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        checkStatus(status, "Set input callback failed");
        
        // Set output callback
        callbackStruct.inputProc        = playbackCallback;
        callbackStruct.inputProcRefCon  = (__bridge void *)(self);
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Global,
                                      kOutputBus,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        checkStatus(status, "Set output callback failed");
        
//        // set echo cancellation
//        UInt32 echoCancellation = 1;
//        checkStatus(AudioUnitSetProperty(audioUnit, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Global, 1, &echoCancellation, sizeof(echoCancellation)), "set echo cancellation failed");
        
        // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
        flag = 0;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_ShouldAllocateBuffer,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &flag,
                                      sizeof(flag));
        checkStatus(status, "Disable buffer allocation for the recorder failed");
        
        mBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
        mBufferList->mNumberBuffers = 1;
        mBufferList->mBuffers[0].mNumberChannels = 1;
        mBufferList->mBuffers[0].mDataByteSize = 2048 * sizeof(short);
        mBufferList->mBuffers[0].mData = (short *)malloc(sizeof(short) * 2048);
        
        // Initialise
        status = AudioUnitInitialize(audioUnit);
        checkStatus(status, "Disable buffer allocation for the recorder failed");
        
//        AudioOutputUnitStart(audioUnit);
        
    }
    return self;
}

- (void)record {
    checkStatus(AudioOutputUnitStart(audioUnit), "audio unit start failed");
    
}

- (void)stop {
    checkStatus(AudioOutputUnitStop(audioUnit), "audio unit stop failed");
}


static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    AudioUnitRecorder *recorder = (__bridge AudioUnitRecorder*)inRefCon;

    AudioUnitRender(recorder->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, recorder->mBufferList);
    printf("+++++++inBus:%d--Frames:%d---byteSize:%d\n", inBusNumber, inNumberFrames, recorder->mBufferList->mBuffers[0].mDataByteSize);
//    printf("+++++++%p\n", recorder->mBufferList);
    return noErr;
}

static OSStatus playbackCallback(void *inRefCon,
                                AudioUnitRenderActionFlags *ioActionFlags,
                                const AudioTimeStamp *inTimeStamp,
                                UInt32 inBusNumber,
                                UInt32 inNumberFrames,
                                AudioBufferList *ioData) {
    AudioUnitRecorder *recorder = (__bridge AudioUnitRecorder*)inRefCon;
    AudioUnitRender(recorder->audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    
    printf("----------------------------------------inbus:%d--frames:%d --size:%d\n", inBusNumber, inNumberFrames, ioData->mBuffers[0].mDataByteSize);
    
//    printf("-----------------------------------------inBus:%d--Frames:%d---byteSize:%d\n", inBusNumber, inNumberFrames, recorder->mBufferList->mBuffers[0].mDataByteSize);
    
//    printf("-----%p\n", ioData);
    return noErr;
}

- (AudioQueuePlayer *)player {
    if (!_player) {
        _player = [[AudioQueuePlayer alloc] init];
    }
    return _player;
}

@end
