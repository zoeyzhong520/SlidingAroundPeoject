//
//  MHBannerCVFlowLayout.h
//  TestProject
//
//  Created by SAIC on 2022/1/13.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MHBannerCVFlowLayout : UICollectionViewFlowLayout

@property (nonatomic, assign) UIEdgeInsets sectionInsets;
@property (nonatomic, assign) CGFloat miniLineSpace;
@property (nonatomic, assign) CGFloat miniInterItemSpace;
@property (nonatomic, assign) CGSize eachItemSize;
@property (nonatomic, assign) BOOL scrollAnimation;/**<是否有分页动画*/
@property (nonatomic, assign) CGPoint lastOffset;/**<记录上次滑动停止时contentOffset值*/
@property (nonatomic, assign) BOOL pageScrollEnable;
@property (nonatomic, copy) void(^pageScrollDirectionBlock)(BOOL); /**滑动方向<手指向左滑动：YES；手指向右滑动：NO>*/

- (instancetype)initWithSectionInset:(UIEdgeInsets)insets andMiniLineSapce:(CGFloat)miniLineSpace andMiniInterItemSpace:(CGFloat)miniInterItemSpace andItemSize:(CGSize)itemSize;
@end

NS_ASSUME_NONNULL_END
