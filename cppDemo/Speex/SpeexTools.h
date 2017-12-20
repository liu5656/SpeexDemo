//
//  SpeexTools.h
//  cppDemo
//
//  Created by lj on 2017/12/18.
//  Copyright © 2017年 lj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpeexTools : NSObject
+ (instancetype)shared;
- (NSData *)compressData:(const void *)data andLengthOfShort:(UInt32)dataSize;
- (NSData *)uncompressData:(const void *)data andLength:(UInt32)dataSize;

@end
