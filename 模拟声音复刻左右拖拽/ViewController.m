//
//  ViewController.m
//  模拟声音复刻左右拖拽
//
//  Created by Zhong Zhaojun on 2022/6/5.
//

#import "ViewController.h"
#import "MHBannerCVFlowLayout.h"
#import "HMShareCollectionViewCell.h"

#define WeakObj(o) autoreleasepool{} __weak typeof(o) o##Weak = o;
#define StrongObj(o) autoreleasepool{} __strong typeof(o) o = o##Weak;
#define kScreenWidth [UIScreen.mainScreen bounds].size.width

@interface ViewController ()<UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) MHBannerCVFlowLayout *flowLayout;
@property (nonatomic, strong) NSMutableArray *dataArray; /// 数据源
@property (nonatomic, strong) NSMutableArray *cardContentOffsetsArray; /// 呈放全部卡片的contentOffset的x
@property (nonatomic, assign) int currentIndex; /// 当前展示卡片的序号

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self createPage];
    [self getCardContentOffsets];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    //取消延迟
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delay) object:nil];
}

/// 构建页面
- (void)createPage {
    self.title = @"模拟声音复刻左右拖拽";
    
    [self.view addSubview:self.collectionView];
    
    //滚动到第二张位置[延迟执行]
    [self performSelector:@selector(delay) withObject:nil afterDelay:1.0];
    //Toast
    [self alertWithTitle:@"客官请稍等"];
}

/// 延迟执行函数
- (void)delay {
    [_collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:true];
    
    @WeakObj(self);
    //延迟处理的原因是collectionView调用scrollToItemAtIndexPath函数时有动画时常
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //调用scrollViewDidEndDecelerating函数，更新当前展示卡片的序号
        [selfWeak scrollViewDidEndDecelerating:selfWeak.collectionView];
    });
}

/// 获取全部卡片的contentOffset值
- (void)getCardContentOffsets {
    //因为左右两张卡片各露出50，并且每两张卡片间距20
    CGFloat itemWidth = (kScreenWidth - 100) + 20;
    
    //以下为iPhone7卡片宽度值
    //1 - 295
    //2 - 590
    //3 - 885
    //...
    
    //把全部卡片的宽度值存放到数组中<数组项展开后为等差数列，差为每张卡片的宽度值>
    for (int i = 0; i < 10; i ++) {
        [self.cardContentOffsetsArray addObject:@(itemWidth*i+itemWidth)];
    }
    NSLog(@"%@", _cardContentOffsetsArray);
}

/// 整个弹框<此弹窗设计2s后自动消失>
- (void)alertWithTitle:(NSString *)title {
    @WeakObj(self);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title ? title : @"标题" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [selfWeak.navigationController presentViewController:alert animated:true completion:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:true completion:nil];
        });
        
    });
}

#pragma mark collectionView代理方法

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.dataArray.count;
    
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
    cell.titleLabel.text = [NSString stringWithFormat:@"%d/10",(int)indexPath.row+1];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    CGFloat itemWidth = ([UIScreen.mainScreen bounds].size.width - 100 ) ;
    CGFloat itemHeight = 350;
    CGSize  size = CGSizeMake(itemWidth, itemHeight);
    
    return  size;
}

#pragma mark scrollView代理方法
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    NSLog(@"%s", __func__);
    
//    NSLog(@"%f === contentOffset - scrollViewDidScroll", scrollView.contentOffset.x);
    
    if (!(scrollView.isTracking || scrollView.isDecelerating) || scrollView != _collectionView) {
        //不是用户滚动的，比如setContentOffset等方法，引起的滚动不需要处理。
        return;
    }
    
    //当屏幕展示某张卡片时，禁止手指向右滑动
    //如下所示屏幕展示第二张卡片，那么不允许滑动到第一张卡片
    if (scrollView.contentOffset.x < [_cardContentOffsetsArray[0] floatValue]) {
        [scrollView setContentOffset:CGPointMake([_cardContentOffsetsArray[0] floatValue], 0) animated:false];
//        [self alertWithTitle:@"禁止滑动到上一张卡片"];
    }
    
    //当屏幕展示某张卡片时，禁止手指向左滑动并翻阅到下下张卡片
    //如下所示屏幕展示第二张卡片，那么不允许滑动到第四张卡片
    if (scrollView.contentOffset.x < [_cardContentOffsetsArray[2] floatValue] && scrollView.contentOffset.x > [_cardContentOffsetsArray[1] floatValue]) {
        [scrollView setContentOffset:CGPointMake([_cardContentOffsetsArray[1] floatValue], 0) animated:false];
        
//        [self alertWithTitle:@"禁止翻阅到下一张卡片"];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    NSLog(@"%s", __func__);
    
//    NSLog(@"%f === contentOffset - scrollViewDidEndDecelerating", scrollView.contentOffset.x);
    
    if (!(scrollView.isTracking || scrollView.isDecelerating) || scrollView != _collectionView) {
        //不是用户滚动的，比如setContentOffset等方法，引起的滚动不需要处理。
        return;
    }
    
    //计算当前展示卡片的序号
    _currentIndex = (int)[_cardContentOffsetsArray indexOfObject:@(scrollView.contentOffset.x)]+1;
    NSLog(@"%d === 当前展示卡片的序号", _currentIndex);
}

#pragma mark Lazy
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        CGFloat itemWidth = (kScreenWidth - 100);
        CGFloat itemHeight = 350;
        UIEdgeInsets sectionInset = UIEdgeInsetsMake(0,0, 0, 0);
        
        MHBannerCVFlowLayout *shareflowLayout = [[MHBannerCVFlowLayout alloc] initWithSectionInset:sectionInset andMiniLineSapce:20 andMiniInterItemSpace:0 andItemSize:CGSizeMake(itemWidth, itemHeight)];
        shareflowLayout.headerReferenceSize = CGSizeMake(50, 0);
        shareflowLayout.footerReferenceSize = CGSizeMake(50, 0);
        shareflowLayout.itemSize = CGSizeMake(itemWidth, itemHeight);
        shareflowLayout.estimatedItemSize = CGSizeMake(0.01, 0.01);
        _flowLayout = shareflowLayout;
        
        //滑动方向<手指向左滑动：YES；手指向右滑动：NO>
        shareflowLayout.pageScrollDirectionBlock = ^(BOOL direction) {
            NSLog(direction ? @"手指向左滑动" : @"手指向右滑动");
        };
        
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 100+60, kScreenWidth, itemHeight+20) collectionViewLayout:shareflowLayout];
        _collectionView.backgroundColor = [UIColor clearColor];
        [_collectionView registerClass:[HMShareCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
        
        _collectionView.delaysContentTouches = YES;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.scrollEnabled = YES;
        _collectionView.bounces = NO;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.panGestureRecognizer.maximumNumberOfTouches = 1;
    }
    return  _collectionView;
}

- (NSMutableArray *)dataArray {
    if (!_dataArray) {
        _dataArray = [NSMutableArray arrayWithArray:@[@"", @"", @"", @"", @"", @"", @"", @"", @"", @""]];
    }
    return  _dataArray;
}

- (NSMutableArray *)cardContentOffsetsArray {
    if (!_cardContentOffsetsArray) {
        _cardContentOffsetsArray = [NSMutableArray arrayWithCapacity:10];
    }
    return _cardContentOffsetsArray;
}

@end
