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


#define kOutputBus  0
#define kInputBus   1

#define  MAX_NB_BYTES 200
#define Speex_Compression_Quality 8

#define Packet_Byte_Compressed  70


@interface AudioUnitRecorder(){
    AudioComponentInstance      audioUnit;
    AudioBufferList             bufferList;
    
    // AUGraph
    AUGraph                     augraph;
    AudioUnit                   mixerUnit;
    AudioUnit                   ioUnit;
}
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
        [self configureAudiounit];
    }
    return self;
}

- (void)configureAUGraph {
    checkStatus(NewAUGraph(&augraph), "new a augraph failed");
    AudioComponentDescription iOUnitDescription = {0};
    iOUnitDescription.componentType             = kAudioUnitType_Output;
    iOUnitDescription.componentSubType          = kAudioUnitSubType_RemoteIO;
    iOUnitDescription.componentManufacturer     = kAudioUnitManufacturer_Apple;
    iOUnitDescription.componentFlags            = 0;
    iOUnitDescription.componentFlagsMask        = 0;
    
    AudioComponentDescription MixUnitDesc       = {0};
    MixUnitDesc.componentType                   = kAudioUnitType_Mixer;
    MixUnitDesc.componentSubType                = kAudioUnitSubType_MultiChannelMixer;
    MixUnitDesc.componentManufacturer           = kAudioUnitManufacturer_Apple;
    MixUnitDesc.componentFlags                  = 0;
    MixUnitDesc.componentFlagsMask              = 0;
    
    AUNode  ioNode;
    AUNode  mixerNode;
    
    checkStatus(AUGraphAddNode(augraph, &iOUnitDescription, &ioNode), "add i/o node failed");
    checkStatus(AUGraphAddNode(augraph, &MixUnitDesc, &mixerNode), "add mixer node failed");
    checkStatus(AUGraphConnectNodeInput(augraph, mixerNode, 0, ioNode, 0), "connect mixer node's output to io node's input");
    checkStatus(AUGraphOpen(augraph), "open augraph failed");
    checkStatus(AUGraphNodeInfo(augraph, mixerNode, NULL, &mixerUnit), "couldn't get instance of mixer unit");
    checkStatus(AUGraphNodeInfo(augraph, ioNode, NULL, &ioUnit), "could't get instaance of i/o unit");
    
    
    /*-------------------------------------------------------------------*/
    UInt32 busCount = 2;
    checkStatus(AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount)), "set mixer unit bus count failed");
    
}

- (void)configureAudiounit {
    [self setupSession];
    AudioComponentDescription           desc;
    desc.componentType                  = kAudioUnitType_Output;
    desc.componentSubType               = kAudioUnitSubType_VoiceProcessingIO;
    //        desc.componentSubType               = kAudioUnitSubType_RemoteIO;
    desc.componentFlags                 = 0;
    desc.componentFlagsMask             = 0;
    desc.componentManufacturer          = kAudioUnitManufacturer_Apple;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
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
    
    // specify format for recording
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &audioFormat,
                                  sizeof(audioFormat));
    checkStatus(status, "Apply format failed for recording");
    
    // specify format for playback
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
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus(status, "Set input callback failed");
    
    // Set output callback
    callbackStruct.inputProc        = playbackCallback;
    callbackStruct.inputProcRefCon  = (__bridge void *)(self);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus(status, "Set output callback failed");
    
    // Initialise
    status = AudioUnitInitialize(audioUnit);
    checkStatus(status, "Disable buffer allocation for the recorder failed");
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
    AudioUnitRecorder *recorder = (__bridge AudioUnitRecorder*)inRefCon;
    ioData->mBuffers[0].mData = recorder->bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = recorder->bufferList.mBuffers[0].mDataByteSize;
    ioData->mBuffers[0].mNumberChannels = recorder->bufferList.mBuffers[0].mNumberChannels;
    ioData->mNumberBuffers = 1;

    return noErr;
}


@end
