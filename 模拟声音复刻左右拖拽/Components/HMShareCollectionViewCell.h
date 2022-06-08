//
//  HMShareCollectionViewCell.h
//  TestProject
//
//  Created by SAIC on 2022/1/13.
//

#import <UIKit/UIKit.h>
#import <Foundation/NSRange.h>

NS_ASSUME_NONNULL_BEGIN

@interface HMShareCollectionViewCell : UICollectionViewCell

@property(nonatomic,strong)UIView* topView;
@property(nonatomic,strong)UIView* bottomView;

@property(nonatomic,strong)UILabel *titleLabel;
@property(nonatomic,strong)UILabel *discLabel;
@property(nonatomic,strong)UIButton *readiconBtn;
@property(nonatomic,assign) BOOL btnPlaying;

@property(nonatomic, copy) void (^playBtnClickBlock) (BOOL playing);


-(void)startButtonAnimating;

-(void)stopButtonAnimating;

//设置不同字体颜色
-(void)addColorWithArray:(NSArray*)array;
@end
NS_ASSUME_NONNULL_END
