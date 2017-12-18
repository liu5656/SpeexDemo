//
//  SpeexTools.m
//  cppDemo
//
//  Created by lj on 2017/12/18.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "SpeexTools.h"
#import "speex.h"

#define  MAX_NB_BYTES 200
#define Speex_Compression_Quality 8

#define Packet_Byte_Compressed  70

@interface SpeexTools ()
{
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
@end

@implementation SpeexTools

#pragma mark tests

#pragma mark echo cancellation

#pragma mark denoise


#pragma mark speex decode
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
    speex_decoder_ctl(dec_state, SPEEX_GET_FRAME_SIZE, &dec_frame_size);
}

#pragma mark speex encoding
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
    speex_encoder_ctl(enc_state, SPEEX_GET_FRAME_SIZE, &enc_frame_size);
    int tmp = Speex_Compression_Quality;
    speex_encoder_ctl(enc_state, SPEEX_SET_QUALITY, &tmp);
}

#pragma mark destroy function
- (void)destroySpeex {
    speex_bits_destroy(&enc_bits);
    speex_decoder_destroy(enc_state);
    
    speex_bits_destroy(&dec_bits);
    speex_decoder_destroy(dec_state);
}

@end
