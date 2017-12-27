//
//  SpeexTools.m
//  cppDemo
//
//  Created by lj on 2017/12/18.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "SpeexTools.h"
#include "speex.h"
#import "speex_preprocess.h"
#import "speex_echo.h"

#define  MAX_NB_BYTES 200
#define Speex_Compression_Quality 8

#define Packet_Byte_Compressed  70

#define Sample_Rate 16000

@interface SpeexTools ()
{
    // speex
    SpeexBits                   enc_bits;
    void                        *enc_state;
    int                         enc_frame_size;
    NSMutableData               *encodingData;
    
    SpeexBits                   dec_bits;
    void                        *dec_state;
    int                         dec_frame_size;
    NSMutableData               *decodingData;
    
    SpeexPreprocessState        *pState;
    
    SpeexEchoState              *echoState;
    
    NSData                      *speakerData;
}
@end

@implementation SpeexTools

+ (instancetype)shared {
    static SpeexTools *shared = nil;
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        shared = [[SpeexTools alloc] init];
        [shared configSpeexEncoder];
        [shared configSpeexDecoder];
    });
    return shared;
}


#pragma mark tests

#pragma mark echo cancellation
static SpeexEchoState *configureSpeexEchoCancellation(int frame_size, int filter_length, SpeexPreprocessState *pstate) {
    SpeexEchoState *state = speex_echo_state_init(frame_size, filter_length);
    int sample_rate = Sample_Rate;
    speex_echo_ctl(state, SPEEX_ECHO_SET_SAMPLING_RATE, &sample_rate);
    speex_preprocess_ctl(pstate, SPEEX_PREPROCESS_SET_ECHO_STATE, state);
    return state;
}

#pragma mark denoise
//speex不是线程安全的，如多线程调用必须加锁
static SpeexPreprocessState *configureSpeexDenoise(int frame_size, int sample_rate) {
    SpeexPreprocessState *state = speex_preprocess_state_init(frame_size, sample_rate);
    int value = 1;
    speex_preprocess_ctl(state, SPEEX_PREPROCESS_SET_DENOISE, &value);
    value = -25;
    speex_preprocess_ctl(state, SPEEX_PREPROCESS_SET_NOISE_SUPPRESS, &value); //降噪强度
    
    
    int agc = 1;
    int level = 24000;
    //actually default is 8000(0,32768),here make it louder for voice is not loudy enough by default.
    speex_preprocess_ctl(state, SPEEX_PREPROCESS_SET_AGC, &agc);// 增益
    speex_preprocess_ctl(state, SPEEX_PREPROCESS_SET_AGC_LEVEL,&level);// 增益后的值
    
    return state;
}

#pragma mark speex decode
- (NSData *)uncompressData:(const void *)data andLength:(UInt32)dataSize {

//    int packets = ceil(dataSize * 1.0 / Packet_Byte_Compressed);
//    char enc_buf[Packet_Byte_Compressed * 2] = {0};
//    memcpy(enc_buf, data, dataSize);
//    char *temp = enc_buf;
//
//    short dec_frames[320] = {0};
////    memset(dec_frames, 0, sizeof(short) * dec_frame_size * packets);
//    short *temp_dec = dec_frames;
//
//    NSMutableData *decodedData = [NSMutableData data];
//    speex_bits_reset(&dec_bits);
//    for (int i = 0; i < packets; i++) {
//        speex_bits_read_from(&dec_bits, temp, Packet_Byte_Compressed);
//        speex_decode_int(dec_state, &dec_bits, temp_dec);
//        [decodedData appendBytes:temp_dec length:dec_bits.nbBits];
//    }
    
    [decodingData appendBytes:data length:dataSize];
    NSInteger total = decodingData.length;
    char *temp = (char *)decodingData.bytes;

    short *dec_frames = (short *)malloc(sizeof(short) * dec_frame_size);
    memset(dec_frames, 0, sizeof(short) * dec_frame_size);

    int packets = floor(total / Packet_Byte_Compressed);
    char enc_buf[Packet_Byte_Compressed];

    // save the left data
    [decodingData replaceBytesInRange:NSMakeRange(0, packets * Packet_Byte_Compressed) withBytes:NULL length:0];

    NSMutableData *decodedData = [NSMutableData data];
    for (int i = 0; i < packets; i++) {
        memset(enc_buf, 0, Packet_Byte_Compressed);
        memcpy(enc_buf, temp, Packet_Byte_Compressed);
        temp += Packet_Byte_Compressed;
        speex_bits_reset(&dec_bits);
        speex_bits_read_from(&dec_bits, enc_buf, Packet_Byte_Compressed);
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
    speex_decoder_ctl(dec_state, SPEEX_GET_FRAME_SIZE, &dec_frame_size);
}

#pragma mark speex encoding
- (NSData *)compressData:(const void *)data andLengthOfShort:(UInt32)dataSize {
//    int packets = (int)ceil((dataSize * 0.5) / enc_frame_size);
//
//    int total = packets * enc_frame_size * 2;
//    char *pcm_buf = (char *)malloc(total);
//    memset(pcm_buf, 0, total);
//    memcpy(pcm_buf, data, dataSize);
//    short *temp = (short *)pcm_buf;
//
//    char enc_buf[MAX_NB_BYTES] = {0}; // 指向编码完成的数据
//    memset(enc_buf, 0, MAX_NB_BYTES);
//    speex_bits_reset(&enc_bits);
//
//    int nbBytes = 0;
//    NSMutableData *encodedData = [NSMutableData data];
//    for (int i = 0; i < packets; i++) {
//        speex_encode_int(enc_state, temp, &enc_bits);
//        nbBytes = speex_bits_write(&enc_bits, enc_buf, MAX_NB_BYTES);
//    }
//    [encodedData appendBytes:enc_buf length:nbBytes];
//    free(pcm_buf);
    
    
    [encodingData appendBytes:data length:dataSize];
    NSInteger total = encodingData.length;
    int packets = (int)floor((total * 0.5) / enc_frame_size);

    Byte temp[1280] = {0};
    memcpy(temp, encodingData.bytes, packets * enc_frame_size * 2);
    short *tempBytes = (short *)temp;

    [encodingData replaceBytesInRange:NSMakeRange(0, packets * enc_frame_size * 2) withBytes:NULL length:0];

    char enc_buf[MAX_NB_BYTES] = {0};
    memset(enc_buf, 0, MAX_NB_BYTES);
    NSMutableData *encodedData = [NSMutableData data];

    
    enc_bits.buf_size = packets * enc_frame_size * 2;
    int nbBytes = 0;
    for (int i = 0; i < packets; i++) {
        speex_bits_reset(&enc_bits);
        speex_encode_int(enc_state, tempBytes, &enc_bits);
        nbBytes = speex_bits_write(&enc_bits, enc_buf, MAX_NB_BYTES);
        [encodedData appendBytes:enc_buf length:(nbBytes)];
    }
    
    
    
//    [encodingData appendBytes:data length:dataSize];
//    NSInteger total = encodingData.length;
//    int packets = (int)floor((total * 0.5) / enc_frame_size);
//    short *tempBytes = (short *)encodingData.bytes;
//    [encodingData replaceBytesInRange:NSMakeRange(0, packets * enc_frame_size * 2) withBytes:NULL length:0];
//
//    char *enc_buf = (char *)malloc(MAX_NB_BYTES);
//    memset(enc_buf, 0, MAX_NB_BYTES);
//
//    NSMutableData *encodedData = [NSMutableData data];
//    for (int i = 0; i < packets; ) {
//
//        speex_preprocess_run(pState, tempBytes);
//
//        speex_bits_reset(&enc_bits);
//        speex_encode_int(enc_state, tempBytes, &enc_bits);
//        int nbBytes = speex_bits_write(&enc_bits, enc_buf, MAX_NB_BYTES);
//        [encodedData appendBytes:enc_buf length:nbBytes];
//        memset(enc_buf, 0, MAX_NB_BYTES);
//        i++;
//        if (i < packets) {
//            tempBytes += enc_frame_size;
//        }
//    }
//    free(enc_buf);
    return encodedData;
}

-(void)configSpeexEncoder{
    encodingData = [NSMutableData data];
    speex_bits_init(&enc_bits);
    
    enc_state = speex_encoder_init(&speex_wb_mode);
    speex_encoder_ctl(enc_state, SPEEX_GET_FRAME_SIZE, &enc_frame_size);
    
    int tmp = Speex_Compression_Quality;
    speex_encoder_ctl(enc_state, SPEEX_SET_QUALITY, &tmp);
    
    pState = configureSpeexDenoise(enc_frame_size, Sample_Rate);
//    echoState = configureSpeexEchoCancellation(enc_frame_size, enc_frame_size * 10, pState);
}

#pragma mark destroy function
- (void)destroySpeex {
    speex_bits_destroy(&enc_bits);
    speex_decoder_destroy(enc_state);
    
    speex_bits_destroy(&dec_bits);
    speex_decoder_destroy(dec_state);
}

@end
