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

#import "speex.h"

#define kOutputBus  0
#define kInputBus   1

#define  MAX_NB_BYTES 200
#define Speex_Compression_Quality 8

#define Packet_Byte_Compressed  70


@interface AudioUnitRecorder(){
    AudioComponentInstance    audioUnit;
    AudioBufferList           *mBufferList;
    
    // speex
    SpeexBits                 enc_bits;
    void                      *enc_state;
    int                       enc_frame_size;
    NSMutableData             *encodingData;
    
    SpeexBits                 dec_bits;
    void                      *dec_state;
    int                       dec_frame_size;
    NSMutableData             *decodingData;
}

@property (nonatomic, strong) AudioQueuePlayer      *player;
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
        [self configSpeexEncoder];
        [self configSpeexDecoder];
        
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
//    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/audio"];
//    BOOL result = [encodedData writeToFile:path atomically:YES];
//    NSLog(@"");
}


static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    AudioUnitRecorder *recorder = (__bridge AudioUnitRecorder*)inRefCon;

    AudioUnitRender(recorder->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, recorder->mBufferList);
    
    
//    NSData *originald = [NSData dataWithBytes:recorder->mBufferList->mBuffers[0].mData length:recorder->mBufferList->mBuffers[0].mDataByteSize];
//    NSData *encoded = [recorder compressData:recorder->mBufferList->mBuffers[0].mData andLengthOfShort:recorder->mBufferList->mBuffers[0].mDataByteSize * 0.5];
//    NSData *decoded = [recorder uncompressData:encoded.bytes andLength:encoded.length];
    
    
    
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

/*=========================================speex encoding====================================================*/

- (NSData *)compressData:(short *)data andLengthOfShort:(UInt32)lengthOfShorts {
    [encodingData appendBytes:data length:lengthOfShorts * 2];
    NSInteger total = encodingData.length;
    int nSamples = (int)floor((total * 0.5) / enc_frame_size);
    printf("run loop times:%d\t", nSamples);
    int length = nSamples * enc_frame_size * 2;
    
    Byte *tempBytes = (Byte *)encodingData.bytes;
    if (tempBytes == NULL) {
        NSLog(@"");
    }
    Byte *bytes = (Byte *)malloc(length);
    if (bytes == NULL) {
        NSLog(@"");
    }
    memset(bytes, 0, length);
    memcpy(bytes, tempBytes, length);
    
    memset(tempBytes, 0, length);
    tempBytes += length;
    encodingData = [NSMutableData dataWithBytes:tempBytes length:(total - length)];
    
    char *cbits = (char *)malloc(MAX_NB_BYTES);
    memset(cbits, 0, MAX_NB_BYTES);
    NSMutableData *encodedData = [NSMutableData data];
    for (int i = 0; i < nSamples; i++) {
        speex_bits_reset(&enc_bits);
        speex_encode_int(enc_state, (short *)bytes, &enc_bits);
        int nbBytes = speex_bits_write(&enc_bits, cbits, MAX_NB_BYTES);
        cbits += (i * nbBytes);
        [encodedData appendBytes:cbits length:nbBytes];
    }
    
//    printf("encoded size: %d\n\n\n", encodedData.length);
    NSLog(@"encoded size :%d", encodedData.length);
    free(bytes);
    return encodedData;
}

-(void)configSpeexEncoder{
    encodingData = [NSMutableData data];
    speex_bits_init(&enc_bits);
    enc_state = speex_encoder_init(&speex_wb_mode);
    encoderCheckError(speex_encoder_ctl(enc_state, SPEEX_GET_FRAME_SIZE, &enc_frame_size), "get enc_frame_size according to speex_wb_mode failed");
    int tmp = Speex_Compression_Quality;
    encoderCheckError(speex_encoder_ctl(enc_state, SPEEX_SET_QUALITY, &tmp), "set auqlity failed");
}

- (NSData *)uncompressData:(char *)bytes andLength:(UInt32)length {
//    short dec_frames[1024];
    short *dec_frames = (short *)malloc(sizeof(short) * dec_frame_size);
    int packets = floor(length / Packet_Byte_Compressed);
    char cbits[Packet_Byte_Compressed];
    NSMutableData *decodedData = [NSMutableData data];
    for (int i = 0; i < packets; i++) {
        memset(cbits, 0, Packet_Byte_Compressed);
        memcpy(cbits, bytes, Packet_Byte_Compressed);
        bytes += Packet_Byte_Compressed;
        
        speex_bits_reset(&dec_bits);
        speex_bits_read_from(&dec_bits, cbits, Packet_Byte_Compressed);
        speex_decode_int(dec_state, &dec_bits, dec_frames);
        
        [decodedData appendBytes:dec_frames length:(dec_frame_size * 2)];
    }
    free(dec_frames);
    return decodedData;
}

- (void)configSpeexDecoder {
    decodingData = [NSMutableData data];
    speex_bits_init(&dec_bits);
    dec_state = speex_decoder_init(&speex_wb_mode);
    checkStatus(speex_decoder_ctl(dec_state, SPEEX_GET_FRAME_SIZE, &dec_frame_size), "get dec_frame_size according to speex_wb_mode failed");
}

- (void)destroySpeex {
    speex_bits_destroy(&enc_bits);
    speex_decoder_destroy(enc_state);
    
    speex_bits_destroy(&dec_bits);
    speex_decoder_destroy(dec_state);
}



void encoderCheckError(int par, char error[]) {
    if (0 != par) {
        printf("%s:%d\n", error, par);
    }
}


@end
