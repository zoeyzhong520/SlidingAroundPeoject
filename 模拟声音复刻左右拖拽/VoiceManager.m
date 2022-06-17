//
//  VoiceManager.m
//  TestProject
//
//  Created by kotei on 2022/1/28.
//

#import "VoiceManager.h"
#import "Constants.h"
#import "MusicModel.h"
@interface VoiceManager()<AVAudioPlayerDelegate,AVAudioRecorderDelegate, EZMicrophoneDelegate, EZRecorderDelegate>
{
    __block int  cunrrentIndex;
    
}

/*
 是否需要绘制声波
 */
@property(nonatomic,assign)BOOL needDrawLine;

@property(nonatomic,assign) int countNumber;
@property(nonatomic,assign)BOOL noRuning;


@end
@implementation VoiceManager
+ (instancetype)shareVoiceManager{
    static VoiceManager *shareManager = nil;
    if (!shareManager) {
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            shareManager = [[VoiceManager alloc] init];
            
            shareManager.microphone = [EZMicrophone microphoneWithDelegate:shareManager];
            [shareManager.microphone setDevice:[[EZAudioDevice inputDevices] firstObject]];
        });
    }
    
    
    return shareManager;
}


#pragma mark 存放录音文件夹的沙盒路径
-(NSString *)recordPathByGroupName:(NSString *)groupName{
    NSString *filePath = [DocumentPath stringByAppendingPathComponent:groupName];  //stringByAppendingString
    //    NSString* userID = [[NSUserDefaults standardUserDefaults] objectForKey:VoiceCopyUserID];
    //
    //    filePath = [filePath stringByAppendingPathComponent:userID];
    if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:NO attributes:nil error:&error];
        if(!error){
            NSLog(@"创建路径error%@",error);
        }else{
            NSLog(@"创建路径成功 存放录音路径的文件夹path为%@",filePath);
        }
    }else{
        NSLog(@"该路径已经存在了");
    }
    return  filePath;
}

#pragma mark 录音设置
/*
 配置录音环境
 */
-(void)setRecordPath{
    //1.设置文件保存路径和名称
    NSString *groupName = [self recordPathByGroupName:@"environmentDetection"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"HHmmss"];
    NSDate *dateNow = [NSDate date];
    NSString *fileName = [[formatter stringFromDate:dateNow] stringByAppendingString:@".wav"]; //苹果手机的录音后缀
    //完整的沙盒路径
    self.fileUrl = [groupName stringByAppendingString:[NSString stringWithFormat:@"/%@",fileName]];
    NSLog(@"path == %@",self.fileUrl);
    
    NSURL* recordUrl = [NSURL URLWithString:self.fileUrl];
    
    [self.microphone startFetchingAudio];
    self.recorder = [[EZRecorder alloc] initWithURL:recordUrl clientFormat:[self.microphone audioStreamBasicDescription] fileType:EZRecorderFileTypeWAV delegate:self];
}

-(NSDictionary *)recordSetting{
    
    NSMutableDictionary* recordSetting = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithFloat:16000], AVSampleRateKey,
                                          [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                          [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                                          [NSNumber numberWithInt:32], AVLinearPCMBitDepthKey,
                                          [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                          [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                          nil];
    
    
    
    return recordSetting;
}



#pragma mark BtnClick
-(void)startRecordVoice{
    self.isTryPlaying = NO;
    self.isCellPlaying = NO;
    self.isRecording =YES;
    self.countNumber =10;
    self.noRuning = NO;
    cunrrentIndex = 0;
    self.needDrawLine = YES;
    
    [self setRecordPath];
}


//停止录音
-(void)confirmRecordVoice{
    NSLog(@"停止录音");
    [self stopRecord];
    
    //获取录音时间
    if (self.recordFinishBlock) {
        NSFileManager *manager = [NSFileManager defaultManager];
        if([manager fileExistsAtPath:self.fileUrl]){
            self.recordFinishBlock(self.fileUrl);
            
        }
    }else{
        NSLog(@"没找到recordFinishBlock");
    }
    
}


-(NSMutableArray *)voicePointArray{
    if (_voicePointArray == nil) {
        _voicePointArray = [NSMutableArray array];
    }
    return _voicePointArray;
}

#pragma mark - EZMicrophoneDelegate

- (void)microphone:(EZMicrophone *)microphone changedPlayingState:(BOOL)isPlaying
{
    //    self.microphoneStateLabel.text = isPlaying ? @"Microphone On" : @"Microphone Off";
    //    self.microphoneSwitch.on = isPlaying;
    NSLog(@"%s",__func__);
}
- (void)microphone:(EZMicrophone *)microphone
  hasAudioReceived:(float **)buffer
    withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    // Getting audio data as an array of float buffer arrays. What does that
    // mean? Because the audio is coming in as a stereo signal the data is split
    // into a left and right channel. So buffer[0] corresponds to the float* data
    // for the left channel while buffer[1] corresponds to the float* data for
    // the right channel.
    
    //
    // See the Thread Safety warning above, but in a nutshell these callbacks
    // happen on a separate audio thread. We wrap any UI updating in a GCD block
    // on the main thread to avoid blocking that audio flow.
    //
    
    NSLog(@"%s",__func__);
    
    __weak typeof (self) weakSelf = self;
    
    if (self.isRecording) {
        
        // GCD定时器
        
        static dispatch_source_t _timer;
        //设置时间间隔
        
        NSTimeInterval period = 1;
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        
        dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
        // 事件回调
        
        dispatch_source_set_event_handler(_timer, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.needDrawLine) {
                    CGFloat vol = [EZAudioUtilities RMS:buffer[0] length:bufferSize];
                    //随机点20～100
                    if (vol>500) {
                        
                        NSLog(@"----大于500");
                        return;
                    }
                    //                    NSLog(@"----vol = %f",vol);
                    NSString* volSrt = [NSString stringWithFormat:@"%0.2f",vol];
                    float newVol =  [volSrt floatValue];
                    
                    CGPoint point = CGPointMake(0, newVol*200);
                    
                    int interval =  (self->cunrrentIndex)%2 ;
                    
                    if (interval == 0) {
                        //插入到数组最前面（动画视图最右边），array添加CGPoint需要转换一下
                        [self.voicePointArray insertObject:[NSValue valueWithCGPoint:point] atIndex:0];
                        if (weakSelf.recordVoicePointBlock) {
                            weakSelf.recordVoicePointBlock(weakSelf.voicePointArray);
                        }
                    }
                    self->cunrrentIndex ++;
                    
                }
                
            });
            
        });
        // 开启定时器
        
        dispatch_resume(_timer);
    }
    
    
}

//------------------------------------------------------------------------------

- (void) microphone:(EZMicrophone *)microphone
      hasBufferList:(AudioBufferList *)bufferList
     withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    //
    // Getting audio data as a buffer list that can be directly fed into the
    // EZRecorder. This is happening on the audio thread - any UI updating needs
    // a GCD main queue block. This will keep appending data to the tail of the
    // audio file.
    //
    if (self.isRecording)
    {
        [self.recorder appendDataFromBufferList:bufferList
                                 withBufferSize:bufferSize];
    }
}

//------------------------------------------------------------------------------
#pragma mark - EZRecorderDelegate
//------------------------------------------------------------------------------

- (void)recorderDidClose:(EZRecorder *)recorder
{
    recorder.delegate = nil;
    NSLog(@"recorderDidClose");
}

//------------------------------------------------------------------------------

- (void)recorderUpdatedCurrentTime:(EZRecorder *)recorder
{
    float time = [recorder currentTime];
    //    __weak typeof (self) weakSelf = self;
    NSString* str = [recorder formattedCurrentTime];
    if (time>20) {
        [self stopRecord];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (self.recordTimeBlock) {
            self.recordTimeBlock(str, time);
        }
        
    });
    
}




//环境检测
-(void)startDetectionEnvironment{
    
    [self setRecordPath];
    
    self.isRecording = YES;
    
    [self performSelector:@selector(stopDetectionEnvironment) withObject:nil afterDelay:5.0];
    
    
}

-(void)stopDetectionEnvironment{
    
    [self stopRecord];
    
    if (self.detectionEnvironmentBlock) {
        NSFileManager *manager = [NSFileManager defaultManager];
        if([manager fileExistsAtPath:self.fileUrl]){
            
            self.detectionEnvironmentBlock(self.fileUrl);
            
        }else{
            self.detectionEnvironmentBlock(@"");
            
        }
    }
    
}

- (void)stopRecord{
    if (self.microphone) {
        [self.microphone  stopFetchingAudio];
    }
    
    self.isRecording = NO;
    self.needDrawLine = NO;
    self.isTryPlaying = NO;
    self.isCellPlaying = NO;
    
    if (self.recorder) {
        [self.recorder closeAudioFile];
    }
    
}

-(void)dealloc{
    NSLog(@"%s",__func__);
}
@end

