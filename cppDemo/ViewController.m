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

//#import "speex.h"


@interface ViewController ()

@property (nonatomic, strong) AudioQueueRecorder *recorder;
@property (nonatomic, strong) AudioQueuePlayer *player;

@property (nonatomic, strong) AudioUnitRecorder *recorder2;

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
        [self.recorder record];
        _recorder.player = self.player;
    }else{
        [sender setTitle:@"record" forState:UIControlStateNormal];
        [_recorder pause];
    }
}

// audio unit 边录边播放
- (IBAction)AudioUnitControl:(UIButton *)sender {
    if (!sender.selected) { // 开始
        [self.recorder2 record];
    }else{ // 暂停
        [self.recorder2 stop];
    }
    sender.selected = !sender.selected;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (AudioQueueRecorder *)recorder {
    if (!_recorder) {
        _recorder = [[AudioQueueRecorder alloc] initWithSampleRate:16000.0 andChannelsPerFrame:1 andBitsPerChannel:16];
    }
    return _recorder;
}

- (AudioQueuePlayer *)player {
    if (!_player) {
        _player = [[AudioQueuePlayer alloc] init];
    }
    return _player;
}

- (AudioUnitRecorder *)recorder2 {
    if (!_recorder2) {
        _recorder2 = [[AudioUnitRecorder alloc] init];
    }
    return _recorder2;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
