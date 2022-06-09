//
//  SoundRecordController.m
//  TestProject
//
//  Created by SAIC on 2022/1/12.
//

#import "SoundRecordController.h"
#import "Constants.h"
#import "RecordButtonView.h"
#import "HMShareCollectionViewCell.h"
#import "MHBannerCVFlowLayout.h"
#import "VoiceManager.h"
#import "TrainTextObject.h"
#import "TextSegObject.h"
#import "KFinishVoiceCopyController.h"
#import "HWDrawView.h"
#import "HLAlertViewBlock.h"
#import "KLoadingAnimation.h"
#import "VoiceCopySDKManager.h"
#import "DDLoadingHUD.h"
#import "AVPlayerManager.h"
#import "MusicModel.h"

@interface SoundRecordController ()<UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
{
    int currentPageIndex ;
    int lastRecordPageIndex ;
    AVPlayerManager* manager;
    
    MHBannerCVFlowLayout *shareflowLayout;
    UIView* whiteView;
    
    float startContentOffsetX;
    float endContentOffsetX;
    
    
}
@property (nonatomic, strong) UICollectionView *shareCollectionView;
@property (nonatomic,strong) NSMutableArray* dataArray;

@property (nonatomic, strong) NSString *textID;
@property (nonatomic, strong) NSMutableArray* recordVoiceArray;
@property (nonatomic, strong) RecordButtonView* recordView;
@property (nonatomic,strong) UIButton* autoReadBtn;// 自动领读
@property (nonatomic,assign) BOOL autoReadTextStatus;// 自动领读
@property (nonatomic,assign) BOOL readClicked;// 领读点击
@property (nonatomic,assign) BOOL needAotoRead;// 领读点击


@property (nonatomic,assign) BOOL hasDetection;  //判断是否通过噪音检测

@property (nonatomic,assign) BOOL isRecording;// 正在录音领读
@property (nonatomic,assign) BOOL isReRecordPage;//这是重录页面



@property (nonatomic,strong) UIButton* changeTextBtn;//换一句按钮


@property (nonatomic,strong) UIView *drawBackView;

@property (nonatomic,strong) HWDrawView* hwDrawView; // 绘制波形图
@property (nonatomic,strong) UILabel* timeLabel; //时间
@property (nonatomic,strong) UIView *backClearView;  //阻止用户点击


@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *pointArray;

@end

@implementation SoundRecordController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ButtonBackColor;
    [self setBackIconColor:[UIColor whiteColor]];
    [self setNavTitleColor:[UIColor whiteColor]];
    
    [self didBecomeActive];
    //后台进前台通知 UIApplicationDidBecomeActiveNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    
    //进入后台UIApplicationDidEnterBackgroundNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    
    
    lastRecordPageIndex = 0;
    self.recordVoiceArray = [[NSMutableArray alloc] initWithCapacity:10];
    _autoReadTextStatus = YES;
    _isRecording = NO;
    _isReRecordPage = NO;
    _readClicked =NO;
    _needAotoRead = NO;
    /*
     1.检测环境
     2.
     
     */
    BOOL microStatus = [MeUtils getMicroPhoneAuthWithBlock:^(BOOL granted) {
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startDetectionEnvironment];
            });
        }else{
            NSLog(@"未授权成功1");
        }
    }];
    if (microStatus) {
        // 环境检测
        [self startDetectionEnvironment];
    }else{
        NSLog(@"未授权成功");
    }
    /*
     换一句移除的数据初始化
     */
    
    currentPageIndex = 0;
    /*
     初始化界面
     */
    [self setNavTitle:@""];
    [self initCollectionView];
    [self initAutoReadButton];
    [self initDrawView];
    [self initProgressView];
    [self initBottomView];
    /*
     查询训练文本
     */
    
    [self startCheckRecordText];
    
    [self.navBackbtn addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [self.view bringSubviewToFront:self.navBar];
    
    
    
}
-(void)didResignActive{
    NSLog(@"%s",__func__);
    [[VoiceManager shareVoiceManager] stopRecord];
    if (self.isRecording) {
        self.isRecording = NO;
        if (self.recordView) {
            [self.recordView interrupRecord];
        }
        
    }
    
    [self stopPlayOnlineVoice];
    
    [self setessionNoActive];
    
}
-(void)didEnterBackground{
    NSLog(@"%s",__func__);
}
-(void)didBecomeActive{
    [self performSelectorOnMainThread:@selector(setSessionActive)
     
                           withObject:nil
     
                        waitUntilDone:NO];
}
-(void)setSessionActive{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [session setActive:YES error:nil];
    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    
}
-(void)setessionNoActive{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    [[AVAudioSession sharedInstance] setActive:NO  error:nil];
}
-(void)stopSession{
    [self performSelectorOnMainThread:@selector(setessionNoActive)
     
                           withObject:nil
     
                        waitUntilDone:NO];
    
}

-(void)goBack{
    [self.navigationController popViewControllerAnimated:YES];
}
/*
 已经训练内容
 */
-(NSMutableArray *)beforeDataArray{
    if (_beforeDataArray == nil) {
        _beforeDataArray = [NSMutableArray array];
    }
    return _beforeDataArray;
}

/*
 cell显示的数据
 */
- (NSMutableArray*)dataArray{
    if (_dataArray == nil) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if (whiteView != nil) {
        whiteView.hidden =NO;
    }
    
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[VoiceManager shareVoiceManager] stopRecord];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    [self stopPlayOnlineVoice];
    
    if (whiteView != nil) {
        whiteView.hidden =YES;
    }
    
    // 开启返回手势
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
    //    如果不想让其他页面的导航栏变为透明 需要重置
    
    
    if (self.isBeingDismissed ||self.isMovingFromParentViewController) {
        NSLog(@"页面通过导航栏pop退出该页面");
        if (lastRecordPageIndex>0) {
            [MeUtils showToastByView:[MeUtils getMainWindow] withText:@"已保存当前录音进度" duration:1 position:CSToastPositionCenter];
            
        }
        
    }else{
        NSLog(@"页面通过导航栏push出该页面 / 页面通过模态化present退出该页面");
    }
    
    //    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}
-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[VoiceManager shareVoiceManager] stopRecord];
    [self stopPlayOnlineVoice];
    
    
    
}

#pragma mark - init

// 进度条
-(void)initProgressView{
    /********** YSProgressView ************/
    NSLog(@"initProgressView");
    self.progressLabel = [[UILabel alloc]init];
    [self.view addSubview:self.progressLabel];
    
    self.progressLabel.text = @"录制进度:1/10";
    self.progressLabel.font = [UIFont systemFontOfSize:14];
    self.progressLabel.textColor =UIColor.whiteColor;
    self.progressLabel.textAlignment = NSTextAlignmentRight;
    
    
    self.progressView = [[YSProgressView alloc] initWithFrame:CGRectMake(50, kNavBarAndStatusBarHeight + 20, SCREEN_WIDTH - 100, 5)];
    self.progressView.progressHeight = 5;
    self.progressView.progressTintColor = RGBColor(95, 170, 198);
    self.progressView.trackTintColor = RGBColor(244, 180, 63);
    //范围为1~10;
    self.progressView.progressValue = 1;
    
    [self.view addSubview:self.progressView];
    [self.progressLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.progressView.mas_right);
        make.bottom.mas_equalTo(self.progressView.mas_top).offset(-10);
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(20);
    }];
    
}
//设置进度条进度
- (void)setProgress:(int)page{
    if (page>=10) {
        page = 10;
    }else{
        page = page +1;
    }
    self.progressLabel.text = [NSString stringWithFormat:@"录制进度:%d/10",page];
    self.progressView.progressValue = page;
    
    if (_dataArray.count>0) {
        TextSegObject *textObject = [_dataArray objectAtIndex:currentPageIndex];
        _recordView.textSegID = [NSString stringWithFormat:@"%@",textObject.seg_id];
        _recordView.textSegText = textObject.seg_text;
        _recordView.textID = self.textID;
        _recordView.taskID =self.taskID;
    }
    
}
//初始化滚动式图
-(void)initCollectionView{
    CGFloat itemWidth = (SCREEN_WIDTH - 100 ) ;
    NSLog(@"itemWidth = %f",itemWidth);
    CGFloat itemHeight = 350;
    if (!kIs_iPhoneX) {
        itemHeight = 300;
        
    }
    NSLog(@"initCollectionView");
    UIEdgeInsets sectionInset =  UIEdgeInsetsMake(0,0, 0, 0);
    
    shareflowLayout = [[MHBannerCVFlowLayout alloc] initWithSectionInset:sectionInset andMiniLineSapce:20 andMiniInterItemSpace:0 andItemSize:CGSizeMake(itemWidth, itemHeight)];
    shareflowLayout.headerReferenceSize = CGSizeMake(50, 0);
    shareflowLayout.footerReferenceSize = CGSizeMake(50, 0);
    shareflowLayout.itemSize =CGSizeMake(itemWidth, itemHeight);
    shareflowLayout.miniLineSpace = 20;
    shareflowLayout.estimatedItemSize = CGSizeMake(0.01, 0.01);
    
    _shareCollectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, kNavBarAndStatusBarHeight+ 60, SCREEN_WIDTH, itemHeight+20) collectionViewLayout:shareflowLayout];
    _shareCollectionView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_shareCollectionView];
    [_shareCollectionView registerClass:[HMShareCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    
    _shareCollectionView.delaysContentTouches = YES;
    _shareCollectionView.delegate = self;
    _shareCollectionView.dataSource = self;
    _shareCollectionView.scrollEnabled = YES;
    //    _shareCollectionView.bounces = NO;
    _shareCollectionView.showsHorizontalScrollIndicator = NO;
    
    _shareCollectionView.panGestureRecognizer.maximumNumberOfTouches =1;
    
    self.backClearView = [[UIView alloc]initWithFrame:CGRectMake(0, _shareCollectionView.frame.origin.y, SCREEN_WIDTH/2 - 30, _shareCollectionView.frame.size.height)];
    self.backClearView.hidden = YES;
    self.backClearView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.backClearView];
    
}
/*
 创建自动领读按钮
 */
-(void)initAutoReadButton{
    NSLog(@"-initAutoReadButton-");
    
    //    float startY= _shareCollectionView.frame.origin.y+ _shareCollectionView.frame.size.height +10;
    //    UIView* backView = [[UIView alloc]initWithFrame:CGRectMake(50, startY, SCREEN_WIDTH -100, 50)];
    //    backView.backgroundColor = RGBColor(249, 249, 249);
    //    [self.view addSubview:backView];
    //    backView.layer.cornerRadius = 5;
    
    
    
    self.autoReadBtn = [[UIButton alloc]init];
    [self.view addSubview:self.autoReadBtn];
    [self.autoReadBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(40);
        make.top.mas_equalTo(_shareCollectionView.mas_bottom).offset(20);
        make.width.mas_equalTo(120);
        make.height.mas_equalTo(30);
    }];
    [self.autoReadBtn setImage:[MeUtils stringWithBundlePath:@"Select_off"] forState:UIControlStateNormal];
    [self.autoReadBtn setImage:[MeUtils stringWithBundlePath:@"Select_on"] forState:UIControlStateSelected];
    [self.autoReadBtn setTitle:@"自动领读" forState:UIControlStateNormal];
    self.autoReadBtn.selected = YES;
    
    NSString* readStatus = [[NSUserDefaults standardUserDefaults] objectForKey:@"autoReadTextStatus"];
    if ( [readStatus isEqualToString:@"UnSelect"]) {
        self.autoReadBtn.selected = NO;
        self.autoReadTextStatus =NO;
    }else{
        self.autoReadTextStatus =YES;
    }
    
    [self.autoReadBtn setTitleColor:UIColor.grayColor forState:UIControlStateNormal];
    self.autoReadBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.autoReadBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, 10, 0, 0)];
    [self.autoReadBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 5, 0, 5)];
    
    [self.autoReadBtn addTarget:self action:@selector(autoReadClick:) forControlEvents:UIControlEventTouchUpInside];
    
    self.changeTextBtn = [[UIButton alloc]init];
    [self.view addSubview:self.changeTextBtn];
    [self.changeTextBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(SCREEN_WIDTH - 160 );
        make.top.mas_equalTo(_shareCollectionView.mas_bottom).offset(20);
        make.width.mas_equalTo(120);
        make.height.mas_equalTo(30);
        
    }];
    [self.changeTextBtn setImage:[MeUtils stringWithBundlePath:@"changeText_icon"] forState:UIControlStateNormal];
    [self.changeTextBtn setImage:[MeUtils stringWithBundlePath:@"changeText_icon"] forState:UIControlStateSelected];
    [self.changeTextBtn setTitle:@"换一句" forState:UIControlStateNormal];
    //    self.changeTextBtn.backgroundColor = UIColor.redColor;
    [self.changeTextBtn setTitleColor:UIColor.grayColor forState:UIControlStateNormal];
    self.changeTextBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.changeTextBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 40)];
    [self.changeTextBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 80, 0, 0)];
    
    [self.changeTextBtn addTarget:self action:@selector(changeTextClick:) forControlEvents:UIControlEventTouchUpInside];
    
}

#pragma mark - DrawView
/*
 创建绘制轨迹的视图
 */
-(void)initDrawView{
    //动画视图
    NSLog(@"initDrawView");
    self.drawBackView = [[UIView alloc] init];
    [self.view addSubview:self.drawBackView];
    [self.drawBackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.top.mas_equalTo(_shareCollectionView.mas_bottom).offset(- 90);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(190);
    }];
    
    HWDrawView *view = [[HWDrawView alloc] init];
    [self.drawBackView  addSubview:view];
    
    [view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.top.mas_equalTo(_shareCollectionView.mas_bottom).offset(- 80);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(150);
    }];
    view.backgroundColor = RGBColor(246, 246, 246);
    self.hwDrawView = view;
    self.drawBackView.hidden = YES;
    
    UILabel* middleLab = [[UILabel alloc]initWithFrame:CGRectMake(SCREEN_WIDTH/2, 5, 1, 160)];
    middleLab.backgroundColor = [MeUtils colorWithHexString:@"#008FBA"];
    [self.drawBackView addSubview:middleLab];
    
    UIView* corView = [[UIView alloc]initWithFrame:CGRectMake(SCREEN_WIDTH/2 - 3, 3, 7, 7)];
    corView.layer.cornerRadius = 3.5;
    corView.backgroundColor = [MeUtils colorWithHexString:@"#008FBA"];
    [self.drawBackView addSubview:corView];
    
    UIView* corView2 = [[UIView alloc]initWithFrame:CGRectMake(SCREEN_WIDTH/2 - 3, 160, 7, 7)];
    corView2.layer.cornerRadius = 3.5;
    corView2.backgroundColor = [MeUtils colorWithHexString:@"#008FBA"];
    [self.drawBackView addSubview:corView2];
    
    /*
     时间标签
     */
    self.timeLabel = [[UILabel alloc] init];
    [self.drawBackView  addSubview:self.timeLabel];
    
    [self.timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(SCREEN_WIDTH/2- 50);
        make.top.mas_equalTo(self.hwDrawView.mas_bottom).offset(10);
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(20);
    }];
    //    self.timeLabel.hidden = YES;
    self.timeLabel.text = @"00:00";
    self.timeLabel.font = [UIFont boldSystemFontOfSize:14];
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    
}
//drawView data
- (NSMutableArray*)pointArray
{
    if (_pointArray == nil) {
        _pointArray = [NSMutableArray array];
    }
    return _pointArray;
}

/*
 开始绘制轨迹
 */
-(void)startDrawLine{
    self.isRecording = YES;
    [self.pointArray removeAllObjects];
    
    self.drawBackView.hidden = NO;
    [self.hwDrawView.pointArray removeAllObjects];
    [self.hwDrawView setPointArray:self.pointArray];
    
    __weak typeof (self) weakSelf = self;
    [VoiceManager shareVoiceManager].recordVoicePointBlock = ^(NSMutableArray *  array) {
        weakSelf.hwDrawView.pointArray = array;
    };
    
}
/*
 停止绘制轨迹
 */
-(void)stopDrawLine{
    //    self.hwDrawView.hidden = YES;
    //    self.timeLabel.hidden = YES;
    self.isRecording = NO;
    self.drawBackView.hidden = YES;
    [self.pointArray removeAllObjects];
    [self.hwDrawView.pointArray removeAllObjects];
    [self.hwDrawView setPointArray:self.pointArray];
}
-(void)clearDrawLine{
    [self.pointArray removeAllObjects];
    [self.hwDrawView.pointArray removeAllObjects];
    [self.hwDrawView setPointArray:self.pointArray];
}
#pragma mark collectionView代理方法

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (_dataArray.count>10) {
        return 10;
    }else{
        return _dataArray.count;
        
    }
    
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return  20;
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return  20;
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    HMShareCollectionViewCell *cell = (HMShareCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    //设置数据
    TextSegObject* object = [_dataArray objectAtIndex:indexPath.row];
    
    cell.titleLabel.text = [NSString stringWithFormat:@"%d/10",(int)indexPath.row+1];
    cell.discLabel.text = [NSString stringWithFormat:@"%@",object.seg_text];
    cell.discLabel.textColor = UIColor.blackColor;
    
    cell.bottomView.hidden = YES;
    cell.bottomView.backgroundColor = UIColor.clearColor;
    cell.playBtnClickBlock = ^(BOOL playing) {
        if (playing) {
            //试听按钮置灰
            if (self.recordView.auditionBtn.selected == YES) {
                self.recordView.auditionBtn.selected =NO;
            }
            
            self.readClicked = YES;
            
            [VoiceManager shareVoiceManager].isCellPlaying = YES;
            [VoiceManager shareVoiceManager].isTryPlaying = NO;
            
            //加载动画
            [[DDLoadingHUD sharedManager] showHUDAddedTo:self.view withTitle:@"加载中" withType:0];
            [DDLoadingHUD setTapToDismissEnabled:YES];
            [self autoReadText];
        }else{
            [VoiceManager shareVoiceManager].isCellPlaying = NO;
            [VoiceManager shareVoiceManager].isTryPlaying = NO;
            
            //停止播放
            [NSObject cancelPreviousPerformRequestsWithTarget:self];
            [self stopPlayOnlineVoice];
            
        }
        
    };
    
    if (indexPath.row == currentPageIndex && object.errorArray.count>0) {
        [cell addColorWithArray:object.errorArray];
        
    }
    
    if (indexPath.row == currentPageIndex ) {
        if (self.isRecording ) {
            cell.bottomView.hidden = YES;
            
        }else{
            cell.bottomView.hidden = NO;
            cell.bottomView.backgroundColor = UIColor.whiteColor;
        }
    }else{
        cell.bottomView.hidden = YES;
    }
    
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat itemWidth = (SCREEN_WIDTH - 100 ) ;
    CGFloat itemHeight = 350;
    if (!kIs_iPhoneX) {
        itemHeight = 300;
        
    }
    CGSize  size = CGSizeMake(itemWidth, itemHeight);
    
    HMShareCollectionViewCell *cell = (HMShareCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.bottomView.hidden = YES;
    cell.bottomView.backgroundColor = UIColor.clearColor;
    NSIndexPath*  currentIndex = [NSIndexPath indexPathForRow:currentPageIndex inSection:0];
    HMShareCollectionViewCell *cell1 = (HMShareCollectionViewCell *)[collectionView cellForItemAtIndexPath:currentIndex];
    if (cell1) {
        if (self.isRecording ) {
            cell1.bottomView.hidden = YES;
        }else{
            cell1.bottomView.hidden = NO;
            cell1.bottomView.backgroundColor = UIColor.whiteColor;
        }
        
    }else{
        cell.bottomView.hidden = YES;
        
    }
    
    return  size;
}
#pragma mark - UIScrollViewDelegate
-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (_isRecording) {
        scrollView.scrollEnabled = NO;
        scrollView.scrollEnabled = YES;
        [MeUtils showToastByView:[MeUtils getMainWindow] withText:@"录制过程中不能切换卡片" duration:1 position:CSToastPositionCenter];
        
        return;
    }
    //    [NSObject cancelPreviousPerformRequestsWithTarget:self];
//    _recordView.userInteractionEnabled = NO;
//    NSLog(@"scrollViewWillBeginDragging = %f",scrollView.contentOffset.x);
    startContentOffsetX =scrollView.contentOffset.x;
    [self stopPlayOnlineVoice];
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    scrollView.panGestureRecognizer.maximumNumberOfTouches =1;
    
    if (_isRecording) {
        _shareCollectionView.scrollEnabled = NO;
        _shareCollectionView.scrollEnabled = YES;
        return;
    }
    
    //禁止左滑
    endContentOffsetX = scrollView.contentOffset.x;
    
    self.backClearView.hidden = YES;
    
    //限制手指向右滑动
    _needAotoRead = YES;
    float contentOffsetX= (lastRecordPageIndex -1)*(SCREEN_WIDTH -80);
    if (scrollView.contentOffset.x < contentOffsetX) {
        [scrollView setContentOffset:CGPointMake(contentOffsetX, 0) animated:NO];
        _needAotoRead = NO;
        
        [scrollView setScrollEnabled:NO];
        [scrollView setScrollEnabled:YES];
    }
    
    //限制手指向左滑动
    contentOffsetX = lastRecordPageIndex*(SCREEN_WIDTH -80);
    if (scrollView.contentOffset.x > contentOffsetX  && scrollView.contentOffset.x < (SCREEN_WIDTH/4.0 + contentOffsetX)) {
        
        [scrollView setContentOffset:CGPointMake(contentOffsetX, 0) animated:NO];
        
        [MeUtils showToastByView:[MeUtils getMainWindow] withText:@"录制完成才能切换至下一张" duration:1 position:CSToastPositionCenter];
        
        _needAotoRead = NO;
        
        [scrollView setScrollEnabled:NO];
        [scrollView setScrollEnabled:YES];
    }
    
    [self getCurrentPage:scrollView.contentOffset.x];
}


- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    
    //    endContentOffsetX= scrollView.contentOffset.x ;
    //    if (endContentOffsetX - startContentOffsetX > 0 && lastRecordPageIndex < currentPageIndex) {
    //
    //           if ((scrollView.isTracking||scrollView.dragging)) {
    //               shareflowLayout.pageScrollEnable = NO;
    //           }
    //    }
//    NSLog(@"scrollViewWillEndDragging = %F",scrollView.contentOffset.x);
    
    [self getCurrentPage:_shareCollectionView.contentOffset.x];
    
}
-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    
//    NSLog(@"scrollViewDidEndDragging = %F",scrollView.contentOffset.x);
    //    [self getCurrentPage:scrollView.contentOffset.x];
    //    self.shareCollectionView.userInteractionEnabled = YES;
    [self getCurrentPage:_shareCollectionView.contentOffset.x];
    //    float conOffet = endContentOffsetX - startContentOffsetX;
    
    //    if (scrollView.isDragging == NO && scrollView.isTracking ==NO) {
    //        [self fixScrollViewCurrentOffsetForPage];
    //        NSLog(@"conOffet >= space = %f",conOffet );
    //        if (conOffet >= (SCREEN_WIDTH -100)) {
    //            // 需要翻页但是 没有翻页
    //            NSLog(@"需要翻页但是 没有翻页");
    //            [self scrollToPage:currentPageIndex];
    //
    //        }
    //    }
    
    
}



-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    _shareCollectionView.userInteractionEnabled = YES;
//    _recordView.userInteractionEnabled = YES;
//    NSLog(@"scrollViewDidEndDecelerating = %f  curentpage = %d",scrollView.contentOffset.x,currentPageIndex);
    [self getCurrentPage:_shareCollectionView.contentOffset.x];
    
    
    float conOffet = endContentOffsetX - startContentOffsetX;
    
    
    //    if (scrollView.decelerating == NO && scrollView.isDragging == NO && scrollView.isTracking ==NO) {
    //        NSLog(@"scrollView.decelerating == NO");
    //        [self fixScrollViewCurrentOffsetForPage];
    //        NSLog(@"conOffet >= space = %f",conOffet );
    //        if (conOffet >= (SCREEN_WIDTH -100)) {
    //            // 需要翻页但是 没有翻页
    //            NSLog(@"需要翻页但是 没有翻页");
    //            [self scrollToPage:currentPageIndex];
    //
    //        }
    //    }
    
    if (scrollView.decelerating == YES) {
//        NSLog(@"scrollView.decelerating == YES");
    }
    
    /*
     判断翻页 才领读，
     */
    
    
    
    
    if (conOffet >= 100 && _needAotoRead ==YES)
    {
//        NSLog(@"currentPageIndex  = %d",currentPageIndex);
        
        if (scrollView.dragging || scrollView.tracking) {
            NSLog(@"需要领读");
        }else{
            NSLog(@"需要领读11");
            [self performSelector:@selector(autoReadText) withObject:nil afterDelay:0.3];
            
        }
    }
    else
    {
        
    }
    
    
    
}
-(void)fixScrollViewCurrentOffsetForPage{
    
    float currentOffsetX = _shareCollectionView.contentOffset.x;
    
    CGFloat itemWidth = (SCREEN_WIDTH - 100) ;
    CGFloat space = itemWidth + 20;
    CGFloat defaultOffsetX  = space* currentPageIndex;
//    NSLog(@"currentOffsetX = %f,",currentOffsetX);
//    NSLog(@"defaultOffsetX = %f,",defaultOffsetX);
    
    if (currentOffsetX != defaultOffsetX) {
        // 没有滑动制定位置
        NSLog(@"没有滑动制定位置");
        [self scrollToPage:currentPageIndex];
    }
    
    
}

-(void)scrollToCurrentOffetX{
    
    
    NSIndexPath*  currentDex = [NSIndexPath indexPathForRow:currentPageIndex inSection:0];
    [_shareCollectionView scrollToItemAtIndexPath:currentDex atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
    
    CGFloat itemWidth = (SCREEN_WIDTH - 100) ;
    CGFloat space = itemWidth + 20;
    CGFloat contentOffsetX  = space* currentPageIndex;
    
    shareflowLayout.lastOffset = CGPointMake(contentOffsetX, 0);
    [self.shareCollectionView reloadData];
    
    
}


//滚动视图滚动到某个页面
-(void)scrollToPage:(int)page{
    
    if (page>=9) {
        page = 9;
    }
    CGFloat itemWidth = (SCREEN_WIDTH - 100) ;
    CGFloat space = itemWidth + 20;
    CGFloat contentOffsetX  = space* page;
    
    [self.shareCollectionView reloadData];
    currentPageIndex = page;
//    NSIndexPath*  currentDex = [NSIndexPath indexPathForRow:currentPageIndex inSection:0];
//    [_shareCollectionView scrollToItemAtIndexPath:currentDex atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
    
    [_shareCollectionView setContentOffset:CGPointMake(contentOffsetX, 0) animated:YES];
    
    shareflowLayout.lastOffset = CGPointMake(contentOffsetX, 0);
    
    [self.shareCollectionView reloadData];
    
}


-(void)getCurrentPage:(CGFloat)contentOffsetX{
//    NSLog(@"getCurrentPage = %f",contentOffsetX);
    
    CGFloat itemWidth = (SCREEN_WIDTH - 100) ;
    CGFloat space = itemWidth + 20;
    int currentPage = (contentOffsetX + SCREEN_WIDTH/2)/space;
    currentPageIndex = currentPage;
    
    if (currentPageIndex  < 0) {
        currentPageIndex = 0;
    }else if (currentPageIndex >= 9){
        currentPageIndex = 9;
    }
    
    [_shareCollectionView layoutSubviews];
    [_shareCollectionView reloadData];
    
    if (lastRecordPageIndex>currentPageIndex) {
//        NSLog(@"lastRecordPageIndex>currentPageIndex");
        
        self.changeTextBtn.hidden =YES;
        _recordView.recordAgainBtn.enabled = YES;
        [_recordView.recordBtn setTitle:@"重新录音" forState:UIControlStateNormal];
        [self getCurrentVoiceUrl];
        shareflowLayout.pageScrollEnable = YES;
        
    }else if(currentPageIndex > lastRecordPageIndex){
        // 出现翻过了
//        NSLog(@"currentPageIndex > lastRecordPageIndex");
        
        shareflowLayout.pageScrollEnable = NO;
        
        CGFloat contentOffsetStartX  = space* lastRecordPageIndex + SCREEN_WIDTH/2 ;
        if (_shareCollectionView.contentOffset.x > contentOffsetStartX) {
            NSLog(@"出现翻过了");
            [self scrollToPage:lastRecordPageIndex];
            
        }
        
    }
    
    else{
        
        shareflowLayout.pageScrollEnable = YES;
        
        self.changeTextBtn.hidden =NO;
        _recordView.recordAgainBtn.enabled = NO;
        if (_isRecording) {
            _recordView.recordAgainBtn.enabled = YES;
            
        }
        [_recordView.recordBtn setTitle:@"开始录音" forState:UIControlStateNormal];
        [self getCurrentVoiceUrl];
        
    }
//    NSLog(@"lastRecordPageIndex  = %d ---- currentPageIndex= %d",lastRecordPageIndex,currentPageIndex);
    
    
    
}
-(void)getCurrentVoiceUrl{
    TextSegObject* object = [_dataArray objectAtIndex:currentPageIndex];
    // 判断试听按钮状态
    if ((object.audio_url.length>0 || object.localUrl.length>0) && !self.isRecording) {
        [self.recordView.auditionBtn setEnabled:YES];
        [self.recordView changeTryButtonType:YES];
        
    }else{
        [self.recordView.auditionBtn setEnabled:NO];
        [self.recordView changeTryButtonType:NO];
        
    }
}

/*
 是否通过了第一次环境检测
 */
- (void)setHasDetection:(BOOL)hasDetection{
    _hasDetection =hasDetection;
    _recordView.canRecord = hasDetection;
}
//初始化底部视图
-(void)initBottomView{
    
    
    whiteView =[[UIView alloc]init];
    [self.view addSubview:whiteView];
    [whiteView mas_makeConstraints:^(MASConstraintMaker *make) {
        
        make.top.mas_equalTo(SCREEN_HEIGHT/2 -50);
        if (!kIs_iphone) {
            make.top.mas_equalTo(SCREEN_HEIGHT/2 -70);
            
        }
        make.left.mas_equalTo(-(SCREEN_HEIGHT/2 - SCREEN_WIDTH/2));
        //        make.centerX.mas_equalTo(SCREEN_WIDTH/2);
        make.width.mas_equalTo(SCREEN_HEIGHT);
        make.height.mas_equalTo(SCREEN_HEIGHT);
    }];
    
    whiteView.layer.cornerRadius =SCREEN_HEIGHT/2;
    whiteView.backgroundColor = UIColor.whiteColor;
    
    _recordView = [[RecordButtonView alloc]initWithFrame:CGRectMake(0, SCREEN_HEIGHT/2, SCREEN_WIDTH, SCREEN_HEIGHT/2)];
    _recordView.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:_recordView];
    [self.view sendSubviewToBack:_recordView];
    [self.view sendSubviewToBack:whiteView];
    [self.view bringSubviewToFront:_shareCollectionView];
    [self.view bringSubviewToFront:self.backClearView];
    
    [self.view layoutIfNeeded];
    
    typeof(self) _weakSelf = self;
    
    _recordView.tryListenClickBlock = ^{
        
        
        //停止自动领读
        [_weakSelf cellStopPlay:NO];
        // 按钮选择状态，开始播放。否则停止播放
        
        BOOL tryPlaying = [VoiceManager shareVoiceManager].isTryPlaying;
        /*
         1.正在试听，就暂停
         */
        
        if (!tryPlaying) {
            //            //开始播放
            
            TextSegObject* obj = [_weakSelf.dataArray objectAtIndex:_weakSelf->currentPageIndex];
            
            if (obj.localUrl.length>0 || obj.audio_url.length>0) {
                NSString* url = @"";
                if (obj.localUrl.length>0) {
                    url =obj.localUrl;
                }else{
                    url =obj.audio_url;
                }
                
                [VoiceManager shareVoiceManager].isTryPlaying = YES;
                if (self.isRecording == NO) {
                    [_weakSelf  playOnlineUrl:url];
                }
            }else{
                NSLog(@"无试听音频");
                [NSObject cancelPreviousPerformRequestsWithTarget:_weakSelf];
                [_weakSelf stopPlayOnlineVoice];
                
                _weakSelf.recordView.auditionBtn.enabled = NO;
                
            }
        }else{
            NSLog(@"停止播放");
            //正在播放
            [VoiceManager shareVoiceManager].isTryPlaying = NO;
            [NSObject cancelPreviousPerformRequestsWithTarget:_weakSelf];
            [_weakSelf stopPlayOnlineVoice];
            
            
        }
        
    };
    
    
    _recordView.startRecordBlock = ^(BOOL canRecord){
        NSLog(@"startRecordBlock");
        
        // 未进行噪音检测
        if (!canRecord) {
            [_weakSelf cellStopPlay:NO];
            [_weakSelf startDetectionEnvironment];
            return;
        }
        //        if(self.shareCollectionView.decelerating == YES){
        ////            延迟执行
        ////            _shareCollectionView
        //            NSLog(@"正在滑动，禁止操作");
        //            sleep(0.3);
        //        }
        
        TextSegObject* recordObj = [_weakSelf.dataArray objectAtIndex:_weakSelf->currentPageIndex];
        _weakSelf.recordView.textSegID = [NSString stringWithFormat:@"%@",recordObj.seg_id];
        _weakSelf.recordView.textSegText = recordObj.seg_text;
        _weakSelf.recordView.textID = _weakSelf.textID;
        _weakSelf.recordView.taskID =_weakSelf.taskID;
        //正在录制时，禁止滑动
        //        _weakSelf.shareCollectionView.userInteractionEnabled = NO;
        _weakSelf.isRecording  = YES;
        _weakSelf.autoReadBtn.hidden = YES;
        _weakSelf.changeTextBtn.hidden = YES;
        //        [_weakSelf.shareCollectionView layoutSubviews];
        [_weakSelf.shareCollectionView reloadData];
        
        
        [_weakSelf stopPlayOnlineVoice];
        
        float delayTime = 0.0;
        if(self.shareCollectionView.decelerating == YES){
            delayTime = 0.5;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_weakSelf.shareCollectionView reloadData];
            
            [_weakSelf clearDrawLine];
            [_weakSelf startDrawLine];
            
            [[VoiceManager shareVoiceManager] startRecordVoice];
            
        });
        
        
        
    };
    //停止录音
    _recordView.stopBlock = ^{
        [_weakSelf stopDrawLine];
        _weakSelf.autoReadBtn.hidden = NO;
        _weakSelf.changeTextBtn.hidden = NO;
        
        [_weakSelf.shareCollectionView reloadData];
        [_weakSelf getCurrentVoiceUrl];
    };
    //停止录制回调  音频上传成功了
    _recordView.recordFinishedBlock = ^(NSDictionary * dict,NSString* filePath) {
        NSLog(@"%@",dict);
        
        /*
         属于重录
         */
        if (self->currentPageIndex < self->lastRecordPageIndex) {
            _weakSelf.isReRecordPage = YES;
            self->lastRecordPageIndex = self->currentPageIndex;
            [_weakSelf setProgress:_weakSelf->lastRecordPageIndex];
            [_weakSelf getCurrentPage:_weakSelf.shareCollectionView.contentOffset.x];
        }
        
        //录制完成时，可以滑动
        NSString* audioUrl = [dict objectForKey:@"audio_url"];
        TextSegObject* recordObj = [_weakSelf.dataArray objectAtIndex:_weakSelf->currentPageIndex];
        recordObj.audio_url = audioUrl;
        recordObj.voiceIndex = _weakSelf->currentPageIndex;
        recordObj.localUrl = filePath;
        
        
        [_weakSelf getCurrentVoiceUrl];
        
        
    };
    
    _recordView.nextButtonBlock = ^(UIButton *  btn) {
        
        NSString* title = btn.titleLabel.text;
        if ([title isEqualToString:@"下一张"]) {
            if ((self->currentPageIndex+1)<=9 && self->currentPageIndex<self->lastRecordPageIndex) {
                [_weakSelf scrollToPage:(self->currentPageIndex + 1)];
                
                [_weakSelf stopPlayOnlineVoice];
                
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
                    [_weakSelf autoReadText];
                });
                
            }
        }else{
            /*
             重录
             */
            [_weakSelf clearDrawLine];
            [[VoiceManager shareVoiceManager] stopRecord];
            
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [_weakSelf startDrawLine];
                [[VoiceManager shareVoiceManager] startRecordVoice];
            });
            
        }
        
    };
    
    _recordView.uploadFailedBlock = ^{
        [_weakSelf getCurrentPage:_weakSelf.shareCollectionView.contentOffset.x];
    };
    
    
    _recordView.currentRecordSuccessBlock = ^{
        
        _weakSelf.view.userInteractionEnabled = NO;
        _weakSelf.recordView.userInteractionEnabled =NO;
        // 提示成功
        _weakSelf.isReRecordPage = NO;
        /*
         移除错误的提示
         */
        [_weakSelf removeErrorArray];
        [_weakSelf.shareCollectionView reloadData];
        
        if ((self->currentPageIndex+1)>9) {
            
            [KLoadingAnimation dismiss];
            
            //            [MeUtils showSuccessToast];
            KFinishVoiceCopyController* ctr = [[KFinishVoiceCopyController alloc]init];
            ctr.taskID =_weakSelf.taskID;
            [_weakSelf.navigationController pushViewController:ctr animated:YES];
            
            
            
        }else{
            self->lastRecordPageIndex = self->currentPageIndex+1;
            self->currentPageIndex = self->currentPageIndex+1;
            if (self->lastRecordPageIndex>=9) {
                self->lastRecordPageIndex = 9;
            }
            
            //            dispatch_async(dispatch_get_main_queue(), ^{
            [_weakSelf scrollToPage:_weakSelf->lastRecordPageIndex];
            [_weakSelf setProgress:_weakSelf->lastRecordPageIndex];
            
            //            });
            /*
             领读
             */
            
            float delayTime = 0.6;
            
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                [KLoadingAnimation dismiss];
                [MeUtils showSuccessToast];
                [_weakSelf.shareCollectionView reloadData];
                [_weakSelf autoReadText];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                _weakSelf.view.userInteractionEnabled = YES;
                _weakSelf.recordView.userInteractionEnabled =YES;
                //                [_weakSelf.shareCollectionView reloadData];
            });
        }
    };
    
    //录音时间返回
    [VoiceManager shareVoiceManager].recordTimeBlock = ^(NSString * _Nonnull timeStr, float time) {
        //        NSLog(@"timeStr = %@",timeStr);
        _weakSelf.timeLabel.text = timeStr;
        if (time>20) {
            [_weakSelf.recordView stopRecord];
            [_weakSelf stopDrawLine];
            _weakSelf.isRecording  = NO;
            _weakSelf.autoReadBtn.hidden = NO;
            _weakSelf.changeTextBtn.hidden = NO;
            [_weakSelf.shareCollectionView reloadData];
            
        }
    };
    
    /*
     录音失败返回
     */
    _recordView.currentRecordFailedBlock = ^(int check_state ,NSString *  errorString) {
        
        [KLoadingAnimation dismiss];
        /*
         重录失败
         */
        [_weakSelf removeErrorArray];
        
        
        NSString* toastString = @"";
        
        if (check_state == 1 || check_state == 2) {
            //语速过快   //语速过慢
            toastString = @"请以匀速朗读";
        }
        else if (check_state == 3) {
            //语速过快
            //            toastString = @"语速过慢";
            NSArray* array = [MeUtils handleStringWithString:errorString];
            NSLog(@"录制失败array = %@",array);
            if (array.count>0) {
                [_weakSelf addColorForCell:array];
                
            }
            toastString = @"部分内容读错了，请重录或换一句";
            
            if (array.count== 0) {
                NSArray*  array1 = [MeUtils handleInsetStringWithString:errorString];
                NSLog(@"录制失败array1 = %@",array1);
                if (array1.count>0) {
                    toastString = @"发现多读了字，请重录";
                    
                }
            }
            
        }else{
            toastString =[MeUtils getFailedToast];
        }
        [_weakSelf.shareCollectionView reloadData];
        
        [MeUtils showToastByView:[MeUtils getMainWindow] withText:toastString duration:2 position:CSToastPositionCenter];
        
        
    };
    
}

-(void)addColorForCell:(NSArray*)array{
    
    NSIndexPath*  currentIndex = [NSIndexPath indexPathForRow:currentPageIndex inSection:0];
    HMShareCollectionViewCell *cell1 = (HMShareCollectionViewCell *)[_shareCollectionView cellForItemAtIndexPath:currentIndex];
    [cell1  addColorWithArray:array];
    
    TextSegObject* object = [_dataArray objectAtIndex:currentIndex.row];
    object.errorArray =[NSArray arrayWithArray:array];
    
}

-(void)removeErrorArray{
    
    NSIndexPath*  currentIndex = [NSIndexPath indexPathForRow:currentPageIndex inSection:0];
    
    TextSegObject* object = [_dataArray objectAtIndex:currentIndex.row];
    object.errorArray =[NSArray array];
    
}



//开始检测环境
-(void)startDetectionEnvironment{
    
    [[DDLoadingHUD sharedManager] showHUDAddedTo:self.navigationController.view  withTitle:@"噪音检测中" withType:1];
    [DDLoadingHUD setTapToDismissEnabled:NO];
    
    
    //    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    // 停止播放
    [self stopPlayOnlineVoice];
    
    //开始噪音检测
    [[VoiceManager shareVoiceManager] startDetectionEnvironment];
    // 回调
    [VoiceManager shareVoiceManager].detectionEnvironmentBlock = ^(NSString * _Nonnull filePath) {
        
        if (filePath.length == 0 ) {
            
            [[DDLoadingHUD sharedManager] dismiss];
            // 环境噪音检测不通过
            [MeUtils showErrorWithString:@"噪音录制失败，请稍后重试"];
            
            self.hasDetection = NO;
            return;
        }
        
        if ( [MeUtils getCurrentNetStatus] ==NO) {
            
            [[DDLoadingHUD sharedManager] dismiss];
            // 环境噪音检测不通过
            [MeUtils showNetworkError];
            self.hasDetection = NO;
            return;
        }
        
        
        
        [Request uploadVoiceDataWithFilePath:filePath withBlock:^(NSDictionary * _Nonnull dict) {
            
            [[DDLoadingHUD sharedManager] dismiss];
            if (dict == nil) {
                [MeUtils showNetworkError];
                self.hasDetection = NO;
                
                return;
            }
            NSLog(@"dict = %@",dict);
            NSDictionary* base = [dict objectForKey:@"base"];
            NSString* ret_code = [base objectForKey:@"ret_code"];
            
            int check_desc = [[dict objectForKey:@"check_state"] intValue];
            if ([ret_code isEqualToString:SuccessCode]  ) {
                if (check_desc ==2) {
                    // 环境噪音检测不通过
                    [self showDetectionEnvironmentAlertView];
                    self.hasDetection = NO;
                }else{
                    self.hasDetection = YES;
                    //自动领读
                    [self.shareCollectionView reloadData];
                    [MeUtils showToastByView:[MeUtils getMainWindow] withText:@"噪音检测通过,可以开始录制" duration:1 position:CSToastPositionCenter];
                    
                    [self autoReadText];
                    
                }
                
                
            }else {
                NSLog(@"未知错误");
                
            }
            
        }];
    };
    
    
}


//查询训练文本
-(void)startCheckRecordText{
    [Request checkRecordTextWithBlock:^(NSDictionary * dict) {
        
        NSDictionary* base = [dict objectForKey:@"base"];
        NSArray* train_textsArray = [dict objectForKey:@"train_texts"];
        NSLog(@"dict = %@",dict);
        
        if (base) {
            NSString* ret_code = [base objectForKey:@"ret_code"];
            if ([ret_code isEqualToString:SuccessCode]) {
                NSLog(@"");
                if (train_textsArray.count>0) {
                    NSLog(@"uservoicesArray = %@",train_textsArray);
                    [self creatData:train_textsArray];
                }else{
                    
                }
            }
            else{
                NSLog(@"查询训练文本失败！");
                
            }
        }
        
    }];
    
}
//添加数据
-(void)creatData:(NSArray*)arrayData{
    
    if (arrayData.count>0) {
        NSDictionary* dict  =[arrayData objectAtIndex:0];
        
        NSArray* text_segs = [dict objectForKey:@"text_segs"];
        NSString* text_id = [dict objectForKey:@"text_id"];
        self.textID = text_id;
        for (NSDictionary* dictionary in text_segs) {
            
            TextSegObject* object = [TextSegObject appWithDict:dictionary];
            if (object) {
                [self.dataArray addObject:object];
            }
        }
        
        /*
         已存在任务
         需要将已经录制的状态保存到本地
         */
        if (self.beforeDataArray.count>0) {
            for (TextSegObject* object in self.beforeDataArray) {
                for (TextSegObject* textObject in self.dataArray) {
                    if ([textObject.seg_id intValue]  == [object.text_seg_id intValue]) {
                        TextSegObject* recordObj = [[TextSegObject alloc]init];
                        recordObj.text_seg_id =object.text_seg_id;
                        
                        recordObj.seg_id =textObject.seg_id;
                        recordObj.seg_text =textObject.seg_text;
                        recordObj.audio_id =object.audio_id;
                        recordObj.audio_url = object.audio_url;
                        recordObj.check_ret = object.check_ret;
                        recordObj.text_id = object.text_id;
                        [self.recordVoiceArray addObject:recordObj];
                        break;
                        
                    }
                    
                }
                
            }
            //重新排序已录制的数据
            self.recordVoiceArray = [NSMutableArray arrayWithArray:[self arraySortASC:_recordVoiceArray]];
            // 然后与数据进行匹配
            [self checkDataWithRecordData:self.recordVoiceArray];
            //滑动到相应页面
            /*
             如果最高一个成功，则加一，否则显示当前
             */
            if (self.recordVoiceArray.count>=0 && self.recordVoiceArray.count<10) {
                
                self->lastRecordPageIndex = (int)self.recordVoiceArray.count;
                if (self->lastRecordPageIndex>=9) {
                    self->lastRecordPageIndex = 9;
                }
                currentPageIndex = (int)self.recordVoiceArray.count;
                [self scrollToPage:(int)(self.recordVoiceArray.count)];
                [self setProgress:lastRecordPageIndex];
                
            }
            
            [_shareCollectionView reloadData];
            
        }else{
            [_shareCollectionView reloadData];
            
            [self creatVoiceTask];
        }
        
        
    }
    
}
// 创建任务
-(void)creatVoiceTask{
    [Request addTaskWithBlock:^(NSDictionary * _Nonnull dict) {
        NSDictionary* base = [dict objectForKey:@"base"];
        NSString* task_id = [dict objectForKey:@"task_id"];
        NSLog(@"dict = %@",dict);
        
        if (base) {
            NSString* ret_code = [base objectForKey:@"ret_code"];
            if ([ret_code isEqualToString:SuccessCode]) {
                self.taskID = task_id;
                
                NSLog(@"创建任务成功！");
                self.recordView.taskID = self.taskID;
                [self resumeTask:@"5006"];
            }
            else{
                NSLog(@"创建任务失败！");
                
            }
        }
    }];
    if (_dataArray.count>0) {
        TextSegObject *textObject = [_dataArray objectAtIndex:currentPageIndex];
        _recordView.textSegID = [NSString stringWithFormat:@"%@",textObject.seg_id];
        _recordView.textSegText = textObject.seg_text;
        _recordView.textID = self.textID;
    }
    
}
// 添加任务断点续传
-(void)resumeTask:(NSString*)categoryID{
    [Request resumeTaskWithCategoryID:categoryID taskID:self.taskID withBlock:^(NSDictionary *  dict) {
        NSDictionary* base = [dict objectForKey:@"base"];
        NSLog(@"dict = %@",dict);
        
        if (base) {
            NSString* ret_code = [base objectForKey:@"ret_code"];
            if ([ret_code isEqualToString:SuccessCode]) {
                
                NSLog(@"添加任务成功！");
            }
            else{
                NSLog(@"添加任务失败！");
            }
        }
    }];
    
}



-(void)autoReadClick:(UIButton*)sender{
    
    sender.selected = !sender.selected;
    if (sender.selected) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Select" forKey:@"autoReadTextStatus"];
        
    }else{
        [[NSUserDefaults standardUserDefaults] setObject:@"UnSelect" forKey:@"autoReadTextStatus"];
        
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.autoReadTextStatus = sender.selected;
    if (self.autoReadTextStatus ==YES && lastRecordPageIndex == currentPageIndex) {
        [self autoReadText];
        
    }
    
}


//自动领读文字
-(void)autoReadText{
    /*
     1.只有选择自动领读，或者点击领读 还有切换新页面才领读，否则不领读
     */
    if (self.autoReadTextStatus ==NO  &&_readClicked == NO ) {
        return;
        
    }
    //已经录制的也不领读
    if (currentPageIndex < lastRecordPageIndex &&_readClicked == NO) {
        return;
    }
    if (_isRecording) {
        [self stopPlayOnlineVoice];
        [[DDLoadingHUD sharedManager] dismiss];
        return;
    }
    
    //还原cell的点击状态
    _readClicked = NO;
    
    
    TextSegObject* currentObject = [_dataArray objectAtIndex:currentPageIndex];
    if (currentObject.seg_text.length>0) {
        [Request readText:currentObject.seg_text withBlock:^(NSDictionary * _Nonnull dict) {
            
            if (dict) {
                NSDictionary* base = [dict objectForKey:@"base"];
                NSString* ret_code = [base objectForKey:@"ret_code"];
                if ([ret_code isEqualToString:SuccessCode]) {
                    NSDictionary* fileDict = [dict objectForKey:@"file"];
                    NSString* fileUrl = [fileDict objectForKey:@"downloadUrl"];
                    
                    
                    BOOL cellPlaying = [VoiceManager shareVoiceManager].isCellPlaying;
                    BOOL tryPlaying = [VoiceManager shareVoiceManager].isTryPlaying;
                    if (cellPlaying == YES || tryPlaying == YES || self.autoReadTextStatus == YES) {
                        if (fileUrl.length>0) {
                            [self cellStopPlay:YES];
                            [[DDLoadingHUD sharedManager] dismiss];
                            [self playOnlineUrl:fileUrl];
                        }
                    }
                    
                }else{
                    //获取失败
                    [self cellStopPlay:NO];
                }
            }else{
                //获取失败
                [[DDLoadingHUD sharedManager] dismiss];
                [self cellStopPlay:NO];
            }
        }];
        
    }
    
    
}
-(void)cellStopPlay:(BOOL)status{
    NSIndexPath*  currentIndex = [NSIndexPath indexPathForRow:currentPageIndex inSection:0];
    HMShareCollectionViewCell *cell  = (HMShareCollectionViewCell *)[self.shareCollectionView cellForItemAtIndexPath:currentIndex];
    if (status) {
        [cell startButtonAnimating];
        [VoiceManager shareVoiceManager].isCellPlaying = YES;
    }else{
        [cell stopButtonAnimating];
        [VoiceManager shareVoiceManager].isCellPlaying = NO;
        
    }
}

//换一句
-(void)changeTextClick:(UIButton*)sender{
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:1.0];
    sender.imageView.transform=CGAffineTransformRotate(sender.imageView.transform, M_PI);
    [UIView commitAnimations];
    
    /*
     1.获取当前的对象
     2.把当前对象添加到移除数组，排序移除数组
     3.把当前对象从数据数组移除
     4.把当前标号的后两个移到当前
     
     */
    [self removeErrorArray];
    
    if (self->currentPageIndex == self->lastRecordPageIndex) {
        if (self.recordView.auditionBtn.selected == YES) {
            self.recordView.auditionBtn.selected =NO;
            [self getCurrentVoiceUrl];
            
        }
    }
    
    TextSegObject* removeObject = [_dataArray objectAtIndex:currentPageIndex];
    
    [_dataArray removeObject:removeObject];
    if (_dataArray.count > currentPageIndex+2) {
        TextSegObject* replaceObject = [_dataArray objectAtIndex:currentPageIndex+2];
        [self.dataArray removeObject:replaceObject];
        [self.dataArray insertObject:replaceObject atIndex:currentPageIndex];
        [self.dataArray addObject:removeObject];
    }
    
    //    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    [self stopPlayOnlineVoice];
    [_shareCollectionView reloadData];
    [self getCurrentVoiceUrl];
    
    [self autoReadText];
    
}

//数组排序
-(NSArray*)arraySortASC:(NSArray*)sourceArray {
    // 数组排序
    // 定义一个数字数组
    //   NSArray *array = @[@(3),@(4),@(2),@(1)];
    // 对数组进行排序
    if (sourceArray.count < 2) {
        return sourceArray;;
    }
    NSArray* result = [sourceArray sortedArrayUsingComparator:^NSComparisonResult(TextSegObject *obj1, TextSegObject *obj2) {
        //NSLog(@"%@~%@",obj1,obj2); // 3~4 2~1 3~1 3~2
        return [obj1.seg_id compare:obj2.seg_id]; // 升序
    }];
    
    //   NSLog(@"result=%@",result);
    return result;
}

-(void)checkDataWithRecordData:(NSArray*)sourceArray{
    NSArray* newDataArray = [NSArray arrayWithArray:self.dataArray];
    
    for (int i = 0; i<sourceArray.count; i++) {
        TextSegObject* object = [sourceArray objectAtIndex:i];
        for (int j = 0; j<newDataArray.count; j++) {
            TextSegObject* textObject = [newDataArray objectAtIndex:j];
            
            if ([textObject.seg_id intValue]  == [object.seg_id intValue]) {
                object.voiceIndex = i;
                object.seg_text = textObject.seg_text;
                
                [self.dataArray removeObjectAtIndex:j];
                [self.dataArray insertObject:object atIndex:i];
                break;
            }
        }
    }
//    NSLog(@"self.dataArray = %@",self.dataArray);
}

-(void)showDetectionEnvironmentAlertView{
    HLAlertViewBlock * alertView = [[HLAlertViewBlock alloc] initWithTittle:@"" message:@"当前环境噪音声高，建议在安静环境中录制" block:^(NSInteger index) {
        if (index == 1) {
            // 是。传入数据
            [self startDetectionEnvironment];
        }else{
            // 否，删除任务
            
        }
    }];
    [alertView setButtonTitle:@"重新检测" cancelButtonTitle:@"取消"];
    [alertView show];
}

#pragma mark - playVoice
-(void)playOnlineUrl:(NSString*)urlString{
    
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    manager =  [AVPlayerManager manager];
    MusicModel* model = [[MusicModel alloc] init];
    model.musicURL =urlString;
    [manager playArray:@[model] index:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(voicePlayDidChange) name:status_key object:nil];
    
}

-(void)stopPlayOnlineVoice{
    
    [VoiceManager shareVoiceManager].isCellPlaying = NO;
    [VoiceManager shareVoiceManager].isTryPlaying = NO;
    if (manager) {
        [manager  pause];
    }else{
        [[AVPlayerManager manager] pause];
    }
}

-(void)voicePlayDidChange{
    NSLog(@"voicePlayDidChange");
    
    [self cellStopPlay:NO];
    self.recordView.auditionBtn.selected = NO;
    [VoiceManager shareVoiceManager].isTryPlaying = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:status_key object:nil];
    
    //    }
}


@end

