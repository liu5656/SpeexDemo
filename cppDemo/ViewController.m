//
//  ViewController.m
//  cppDemo
//
//  Created by lj on 2017/12/7.
//  Copyright © 2017年 lj. All rights reserved.
//

#import "ViewController.h"
#import "AudioQueueRecorder.h"
#import "AudioQueuePlayer.h"

#import "AudioUnitRecorder.h"

#import "AudioUnitPlayer.h"
#import "AudioUnitRecorder2.h"

#import "AudioUnitPlayAndRecord.h"

#import "SpeexTools.h"

//#import "speex.h"


@interface ViewController ()<AudioUnitRecorderDelegate>

@property (nonatomic, strong) AudioQueueRecorder *AQrecorder;
@property (nonatomic, strong) AudioQueuePlayer *AQplayer;

@property (nonatomic, strong) AudioUnitRecorder *recorder1;

@property (nonatomic, strong) AudioUnitPlayer *AUplayer;
@property (nonatomic, strong) AudioUnitRecorder2 *AUrecorder;

@property (nonatomic, strong) AudioUnitPlayAndRecord *playAndrecorder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    speex_encoder_init(&speex_nb_mode);
}

// auido queue 边录边播放
- (IBAction)recordControl:(UIButton *)sender {
    if ([sender.titleLabel.text isEqualToString:@"record"]) {
        [sender setTitle:@"stop" forState:UIControlStateNormal];
        [self.AQrecorder record];
        _AQrecorder.player = self.AQplayer;
    }else{
        [sender setTitle:@"record" forState:UIControlStateNormal];
        [_AQrecorder pause];
    }
}

// 测试speex预处理
- (IBAction)speexPreprocessTest:(UIButton *)sender {
    if (sender.selected) {
        [self.AUrecorder stopRecord];
    }else{
        [self.AUrecorder startRecord];
    }
    sender.selected = !sender.selected;
}

// audio unit 边录边播放
- (IBAction)AudioUnitControl:(UIButton *)sender {
    if (!sender.selected) { // 开始
        [self.recorder1 record];
    }else{ // 暂停
        [self.recorder1 stop];
    }
    sender.selected = !sender.selected;
}
- (IBAction)audioUnitPlay:(UIButton *)sender {
    [self.AUplayer play];
}

- (IBAction)audioUnitRecord:(UIButton *)sender {
    if (sender.selected) {
        [self.AUrecorder stopRecord];
    }else{
        [self.AUrecorder startRecord];
    }
    sender.selected = !sender.selected;
}

- (IBAction)audioUnitRecordAndPlay:(UIButton *)sender {
    if (sender.selected) {
        [self.playAndrecorder stop];
    }else{
        [self.playAndrecorder playAndRecord];
    }
    sender.selected = !sender.selected;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (AudioQueueRecorder *)AQrecorder {
    if (!_AQrecorder) {
        _AQrecorder = [[AudioQueueRecorder alloc] initWithSampleRate:16000.0 andChannelsPerFrame:1 andBitsPerChannel:16];
    }
    return _AQrecorder;
}

- (AudioQueuePlayer *)AQplayer {
    if (!_AQplayer) {
        _AQplayer = [[AudioQueuePlayer alloc] init];
    }
    return _AQplayer;
}

- (AudioUnitRecorder *)recorder1 {
    if (!_recorder1) {
        _recorder1 = [[AudioUnitRecorder alloc] init];
    }
    return _recorder1;
}

- (AudioUnitPlayer *)AUplayer {
    if (!_AUplayer) {
        _AUplayer = [[AudioUnitPlayer alloc] init];
    }
    return _AUplayer;
}

- (AudioUnitRecorder2 *)AUrecorder {
    if (!_AUrecorder) {
        _AUrecorder = [[AudioUnitRecorder2 alloc] initWithDelegate:self];
    }
    return _AUrecorder;
}

- (AudioUnitPlayAndRecord *)playAndrecorder {
    if (!_playAndrecorder) {
        _playAndrecorder = [[AudioUnitPlayAndRecord alloc] init];
    }
    return _playAndrecorder;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark AudioUnitRecorderDelegate
- (void)AURecorder:(AudioUnitRecorder2 *)recoder andData:(NSData *)data {
    if (data.length == 0) return;
    @autoreleasepool {
//            NSLog(@"++++++++++%@",data);
        NSData *temp = [[SpeexTools shared] compressData:data.bytes andLengthOfShort:(UInt32)data.length];
        NSData *decode = [[SpeexTools shared] uncompressData:temp.bytes andLength:(UInt32)temp.length];
//            NSLog(@"----------%@",decode);
//        printf("\n\n\n");

        [self.AQplayer playWithData:(Byte *)decode.bytes andSize:(UInt32)decode.length];
        
//        [self.AQplayer playWithData:data.bytes andSize:data.length];
    }
}


@end
