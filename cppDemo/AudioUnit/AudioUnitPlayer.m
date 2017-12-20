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

#import "SpeexTools.h"

#define INPUT_BUS 1
#define OUTPUT_BUS 0

#define CONST_BUFFER_SIZE 0x10000

@implementation AudioUnitPlayer
{
    NSData *audioData;
    NSMutableData *encodedData;
    NSMutableData *decodedData;
    
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    NSInputStream *inputStream;
}

- (void)play {
    [self startOtherThread];
    [self initPlayer];
    AudioOutputUnitStart(audioUnit);
}

- (void)initPlayer {
    
//    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"originalpcm" withExtension:nil];
    
    audioData = [NSData dataWithContentsOfURL:url];
    
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
    
//    AudioStreamBasicDescription oformat = {0};
//    UInt32 size = sizeof(oformat);
//    AudioUnitGetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &oformat, &size);
    
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

static UInt32 num = 0;
OSStatus PlayCalback(void *inRefCon,
                     AudioUnitRenderActionFlags *ioActionFlags,
                    const AudioTimeStamp *inTimeStamp,
                    UInt32 inBusNumber,
                    UInt32 inNumberFrames,
                     AudioBufferList * __nullable    ioData) {
    AudioUnitPlayer *player = (__bridge AudioUnitPlayer *)inRefCon;
    memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
//    ioData->mBuffers[0].mDataByteSize = (UInt32)[player->inputStream read:ioData->mBuffers[0].mData maxLength:ioData->mBuffers[0].mDataByteSize];
    
//    UInt32 length = ioData->mBuffers[0].mDataByteSize;
//    if ((num + length) < player->audioData.length) {
//        NSData *temp = [player->audioData subdataWithRange:NSMakeRange(num, length)];
//        ioData->mBuffers[0].mData = temp.bytes;
//        num += length;
//    }

    UInt32 length = ioData->mBuffers[0].mDataByteSize;
    if (length <= player->decodedData.length) {
        NSData *temp = [player->decodedData subdataWithRange:NSMakeRange(0, length)];
        ioData->mBuffers[0].mData = temp.bytes;
        [player->decodedData replaceBytesInRange:NSMakeRange(0, length) withBytes:nil length:0];
    }
    
    
    
    
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

- (void)startOtherThread {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"encodedpcm" withExtension:nil];
    encodedData = [NSMutableData dataWithContentsOfURL:url];
    decodedData = [NSMutableData data];
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(startUncompressData) object:nil];
    [operation start];
}

- (void)startUncompressData {
    while (encodedData.length > 70) {
        NSData *xx = [encodedData subdataWithRange:NSMakeRange(0, 70)];
        NSData *temp = [[SpeexTools shared] uncompressData:xx.bytes andLength:(UInt32)xx.length];
        [decodedData appendData:temp];
        [encodedData replaceBytesInRange:NSMakeRange(0, xx.length) withBytes:nil length:0];
    }
}






















@end
