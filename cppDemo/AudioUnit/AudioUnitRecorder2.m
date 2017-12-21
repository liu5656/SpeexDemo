//
//  AudioUnitRecorder2.m
//  cppDemo
//
//  Created by lj on 2017/12/18.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "AudioUnitRecorder2.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>


#define INPUT_BUS 1

#define MAX_FRAMES 1024

@interface AudioUnitRecorder2()
{
    AudioUnit           audioUnit;
}
@property (nonatomic, weak) id<AudioUnitRecorderDelegate> delegate;

@property (nonatomic, strong) NSMutableData *audioData;

@end

@implementation AudioUnitRecorder2

- (instancetype)initWithDelegate:(id<AudioUnitRecorderDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        [self configAudioUnitRecorder];
    }
    return self;
}

- (void)setupSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
//    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
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

- (BOOL)initializeAudioUnit {
    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    return audioUnit ? YES : NO;
}

- (BOOL)setupEnableIO {
    UInt32 flag = 1;
    OSStatus status = AudioUnitSetProperty(audioUnit,
                                           kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Input,
                                           INPUT_BUS,
                                           &flag,
                                           sizeof(flag));
    return (status == noErr) ? YES : NO;
}

- (BOOL)setupStreamFormat {
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = 16000;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBytesPerFrame = 2;
    outputFormat.mBytesPerPacket = 2;
    outputFormat.mBitsPerChannel = 16;
    OSStatus status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  INPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    return (status == noErr) ? YES : NO;
}

- (BOOL)setupCallback {
    AURenderCallbackStruct          callbackStruct;
    callbackStruct.inputProc        = recordingCallback;
    callbackStruct.inputProcRefCon  = (__bridge void *)(self);
    OSStatus status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  INPUT_BUS,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    return (status == noErr) ? YES : NO;
}

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    AudioUnitRecorder2 *recorder = (__bridge AudioUnitRecorder2*)inRefCon;
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;
    AudioUnitRender(recorder->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);

    [recorder handleRecordData:[NSData dataWithBytes:bufferList.mBuffers[0].mData length:bufferList.mBuffers[0].mDataByteSize]];
    return noErr;
}

- (void)configAudioUnitRecorder {
    [self setupSession];
    [self initializeAudioUnit];
    [self setupEnableIO];
    [self setupStreamFormat];
    [self setupCallback];
    OSStatus status = AudioUnitInitialize(audioUnit);
    if (status != noErr) {
        NSLog(@"initialize audiounit failed:%d", status);
        return;
    }
}

- (void)startRecord {
        OSStatus status = AudioOutputUnitStart(audioUnit);
        NSLog(@"");
}

- (void)stopRecord {
        AudioOutputUnitStop(audioUnit);
//        AudioComponentInstanceDispose(audioUnit);
//        audioUnit = NULL;
//        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/2212.pcm"];
//        BOOL result = [self.audioData writeToFile:path atomically:YES];
//        NSLog(@"save result:%d", result);
}

- (void)handleRecordData:(NSData *)data {
    if (data.length == 0) return;
    if ([self.delegate respondsToSelector:@selector(AURecorder:andData:)]) {
        [self.delegate AURecorder:self andData:data];
//        [self.audioData appendData:data];
    }
}


- (NSMutableData *)audioData {
    if (!_audioData) {
        _audioData = [NSMutableData data];
    }
    return _audioData;
}

@end
