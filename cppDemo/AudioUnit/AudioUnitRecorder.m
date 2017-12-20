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

#import "SpeexTools.h"

#import "speex.h"

#define kOutputBus  0
#define kInputBus   1

#define  MAX_NB_BYTES 200
#define Speex_Compression_Quality 8

#define Packet_Byte_Compressed  70


@interface AudioUnitRecorder(){
    AudioComponentInstance      audioUnit;
    AudioBufferList             bufferList;
    
    // speex
    SpeexBits                   enc_bits;
    void                        *enc_state;
    int                         enc_frame_size;
    NSMutableData               *encodingData;
    NSMutableData               *encodedData;
    
    SpeexBits                   dec_bits;
    void                        *dec_state;
    int                         dec_frame_size;
    NSMutableData               *decodingData;
    NSMutableData               *decodedData;
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
        
        encodedData = [NSMutableData data];
        decodedData = [NSMutableData data];
        
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
        
        // Initialise
        status = AudioUnitInitialize(audioUnit);
        checkStatus(status, "Disable buffer allocation for the recorder failed");
                
    }
    return self;
}

- (void)record {
//    [self testDecodedPlay];
    checkStatus(AudioOutputUnitStart(audioUnit), "audio unit start failed");
//    [self speexUncompressAfterCompressUnittest];
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
    [recorder->encodedData appendData:[[SpeexTools shared] compressData:recorder->bufferList.mBuffers[0].mData andLengthOfShort:recorder->bufferList.mBuffers[0].mDataByteSize]];
    NSLog(@"------------");
    return noErr;
}

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    AudioUnitRecorder *recorder = (__bridge AudioUnitRecorder*)inRefCon;
    NSLog(@"              ------------");
    ioData->mBuffers[0].mData = recorder->bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = recorder->bufferList.mBuffers[0].mDataByteSize;
    ioData->mBuffers[0].mNumberChannels = recorder->bufferList.mBuffers[0].mNumberChannels;
    ioData->mNumberBuffers = 1;
    
//    memset(ioData, 0, inNumberFrames * 2);
//    NSData *data = [recorder getUncompressDataLength:inNumberFrames * 2];
//    if (data >= (inNumberFrames * 2)) {
//        ioData->mBuffers[0].mData = data.bytes;
////        ioData->mBuffers[0].mData = recorder->bufferList.mBuffers[0].mData;
//        ioData->mBuffers[0].mDataByteSize = recorder->bufferList.mBuffers[0].mDataByteSize;
//        ioData->mBuffers[0].mNumberChannels = recorder->bufferList.mBuffers[0].mNumberChannels;
//        ioData->mNumberBuffers = 1;
//    }

    return noErr;
}


/*=========================================speex encoding====================================================*/

- (NSData *)getUncompressDataLength:(UInt32)length {
    NSInteger total = encodedData.length;
    int i = 0;
    while (total > Packet_Byte_Compressed) {
        NSData *packet = [encodedData subdataWithRange:NSMakeRange(i * Packet_Byte_Compressed, Packet_Byte_Compressed)];
        NSData *data = [[SpeexTools shared] uncompressData:(char *)packet.bytes andLength:(UInt32)packet.length];
        [decodedData appendData:data];
        if (decodedData.length > length) {
            break;
        }
        total -= Packet_Byte_Compressed;
        if (total > Packet_Byte_Compressed) {
            i++;
        }
    }
    if (decodedData.length > length) {
        NSData *data = [decodedData subdataWithRange:NSMakeRange(0, length)];
        [decodedData replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
        return data;
    }
    [encodedData replaceBytesInRange:NSMakeRange(0, i * Packet_Byte_Compressed) withBytes:NULL length:0];
    return nil;
}


- (void)testDecodedPlay {
    [self configSpeexDecoder];
    encodingData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"encodedpcm" ofType:nil]];
    enc_frame_size = encodingData.length;
    
}

- (void)speexUncompressAfterCompressUnittest {
    BOOL result;
    NSData *encoded = [self speexCompressTest];
    [encoded writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/encodedpcm"] atomically:YES];
    
    NSData *decoded = [self speexUncompressTest:encoded];
     result = [decoded writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/decodedpcm"] atomically:YES];
    NSLog(@"%d", result);
}

- (NSData *)speexUncompressTest:(NSData *)encoded{
    [self configSpeexDecoder];
    NSMutableData *decoded = [NSMutableData data];
    Byte *bytes = (Byte *)encoded.bytes;
    NSInteger length = encoded.length;
    
    char *temp = (char *)malloc(sizeof(char) * Packet_Byte_Compressed);
    while (length >= Packet_Byte_Compressed) {
        memset(temp, 0, Packet_Byte_Compressed);
        memcpy(temp, bytes, Packet_Byte_Compressed);
        NSData *data = [self uncompressData:temp andLength:Packet_Byte_Compressed];
        [decoded appendData:data];
        length -= Packet_Byte_Compressed;
        bytes += Packet_Byte_Compressed;
    }
    free(temp);
    return decoded;
}

- (NSData *)speexCompressTest {
    [self configSpeexEncoder];
    NSMutableData *encoded = [NSMutableData data];
    NSData *originalData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"originalpcm" ofType:nil]];
    Byte *bytes = (Byte *)originalData.bytes;
    NSInteger length = originalData.length;
    short *temp = (short *)malloc(sizeof(short) * enc_frame_size);
    while (length >= (enc_frame_size * 2)) {
        memset(temp, 0, sizeof(short) * enc_frame_size);
        memcpy(temp, bytes, sizeof(short) * enc_frame_size);
        NSData *data = [self compressData:temp andLengthOfShort:enc_frame_size];
        
        [encoded appendData:data];
        bytes += (enc_frame_size * sizeof(short));
        length -= (enc_frame_size * 2);
    }
    free(temp);
    return encoded;
}

- (NSData *)compressData:(short *)data andLengthOfShort:(UInt32)lengthOfShorts {
    [encodingData appendBytes:data length:lengthOfShorts * 2];
    NSInteger total = encodingData.length;
    int nSamples = (int)floor((total * 0.5) / enc_frame_size);
    printf("run loop times:%d\n", nSamples);
    int length = nSamples * enc_frame_size * 2;
    
    Byte *tempBytes = (Byte *)encodingData.bytes;
    
    Byte *bytes = (Byte *)malloc(length);
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
    short *dec_frames = (short *)malloc(sizeof(short) * dec_frame_size);
    memset(dec_frames, 0, sizeof(short) * dec_frame_size);
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
