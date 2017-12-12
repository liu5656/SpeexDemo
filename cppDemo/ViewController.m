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


@interface ViewController ()

@property (nonatomic, strong) AudioQueueRecorder *recorder;
@property (nonatomic, strong) AudioQueuePlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

}

- (IBAction)playControl:(UIButton *)sender {
    if ([sender.titleLabel.text isEqualToString:@"play"]) {
        [sender setTitle:@"pause" forState:UIControlStateNormal];
    }else{
        [sender setTitle:@"play" forState:UIControlStateNormal];
        _recorder.player = self.player;
    }
}
- (IBAction)recordControl:(UIButton *)sender {
    if ([sender.titleLabel.text isEqualToString:@"record"]) {
        [sender setTitle:@"stop" forState:UIControlStateNormal];
        [_recorder pause];
    }else{
        [sender setTitle:@"record" forState:UIControlStateNormal];
        [self.recorder record];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self player];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
