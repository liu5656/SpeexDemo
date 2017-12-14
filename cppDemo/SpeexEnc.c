//
//  SpeexEnc.c
//  cppDemo
//
//  Created by lj on 2017/12/13.
//  Copyright © 2017年 lj. All rights reserved.
//

#include "SpeexEnc.h"
#include "speex.h"

#define FRAME_SIZE 160

void compressAudio(char *argv[]) {
    char *inFile;
    FILE *fin;
    short in[FRAME_SIZE];
    float input[FRAME_SIZE];
    char cbits[200];
    int nbbytes;
    // holds the state of the encoder
    void *state;
    // holds bits so they can be read and written to by the speex routines
    SpeexBits bits;
    int i;
    // create a new encoder state in narrowband mode
    state = speex_encoder_init(&speex_nb_mode);
    
    // set the quality to 8 (15kbps)
    int tmp = 8;
    speex_encoder_ctl(state, SPEEX_SET_QUALITY, &tmp);
    
    inFile = argv[1];
    fin = fopen(inFile, "r");
    
    // Initialization of the structure that holds the bits
    speex_bits_init(&bits);
    
    while (1) {
        // Read a 16 bits/sample audio frame
        fread(in, sizeof(short), FRAME_SIZE, fin);
        if (feof(fin)) {
            break;
        }
        // Copy the 16 bits values to float so speex can work on them
        for (i = 0; i < FRAME_SIZE; i++)
            input[i] = in[i];
            
        // Flush all the bits in the structs so we can encode a new frame
        speex_bits_reset(&bits);
        
        // Encode the frame
        speex_encode(state, input, &bits);
        
        // Copy the bits to an array of char thar can be written
        nbbytes = speex_bits_write(&bits, cbits, 200);
        
        // write the size of the frame first, This is what sampledec expects byt it's likely to be different in your own application
        fwrite(&nbbytes, sizeof(int), 1, stdout);
        /// write the compressed data
        fwrite(cbits, 1, nbbytes, stdout);
        
    }
    
    // Destroy the encoder state
    speex_encoder_destroy(state);
    // Destroy the bit-packing struct
    speex_bits_destroy(&bits);
    fclose(fin);
    
}


























