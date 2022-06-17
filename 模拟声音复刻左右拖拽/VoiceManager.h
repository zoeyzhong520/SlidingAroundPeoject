//
//  VoiceManager.h
//  TestProject
//
//  Created by kotei on 2022/1/28.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
//
// First import the EZAudio header
//
#import "EZAudio.h"

//
// By default this will record a file to the application's documents directory
// (within the application's sandbox)
//
#define kAudioFilePath @"test.wav"


NS_ASSUME_NONNULL_BEGIN

@interface VoiceManager : NSObject
//@property(nonatomic,strong)AVAudioPlayer *player;  //播放器
//@property(nonatomic,strong)AVAudioRecorder *recorder; //录音
@property(nonatomic,strong)NSURL *recordUrl; //录音文件路径
@property(nonatomic,strong)NSString *fileUrl; //存储路径
@property(nonatomic, copy) void (^recordBlock) (NSString* filePath);
@property(nonatomic, copy) void (^recordVoicePointBlock) (NSMutableArray* array);
@property(nonatomic, copy) void (^recordFinishBlock) (NSString* filePath);
@property(nonatomic, copy) void (^detectionEnvironmentBlock) (NSString* filePath);

@property(nonatomic, copy) void (^recordTimeBlock) (NSString* timeStr,float time);

//
// The microphone component
//
@property (nonatomic, strong) EZMicrophone *microphone;
//
// The audio player that will play the recorded file
//

//
// The recorder component
//
@property (nonatomic, strong) EZRecorder *recorder;
@property (nonatomic, strong) NSMutableArray *voicePointArray;;


@property (nonatomic, assign) BOOL isRecording;

@property (nonatomic, assign) BOOL isTryPlaying;
@property (nonatomic, assign) BOOL isCellPlaying;


+ (instancetype)shareVoiceManager;
-(void)startRecordVoice;
-(void)confirmRecordVoice;
-(NSString *)recordPathByGroupName:(NSString *)groupName;

-(void)stopRecord;
//环境检测
-(void)startDetectionEnvironment;




@end

NS_ASSUME_NONNULL_END
