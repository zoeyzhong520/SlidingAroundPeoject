//
//  HMShareCollectionViewCell.m
//  TestProject
//
//  Created by SAIC on 2022/1/13.
//

#import "HMShareCollectionViewCell.h"

@interface HMShareCollectionViewCell ()

@end

@implementation HMShareCollectionViewCell
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        //设置控件
        
        self.backgroundColor = [UIColor clearColor];
        
        _topView =[[UIView alloc]initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height -100)];
        _topView.backgroundColor = [UIColor orangeColor];
        [self.contentView addSubview:_topView];
        CAGradientLayer *gradientLayer = [CAGradientLayer layer];
        UIColor* topColor = [UIColor colorWithRed:175/255.0 green:213/255.0 blue:235/255.0 alpha:1];
        gradientLayer.colors = @[(__bridge id) topColor.CGColor,  (__bridge id)[UIColor whiteColor].CGColor];
        gradientLayer.locations = @[@0, @1.0];
        gradientLayer.startPoint = CGPointMake(0, 0);
        gradientLayer.endPoint = CGPointMake(0, 1);
        gradientLayer.frame = CGRectMake(0, 0, _topView.frame.size.width, _topView.frame.size.height);
        [_topView.layer addSublayer:gradientLayer];
        gradientLayer.cornerRadius = 0;
            
        
        
        _bottomView =[[UIView alloc]initWithFrame:CGRectMake(0, _topView.frame.size.height, frame.size.width, 100)];
        [self.contentView addSubview:_bottomView];
        _bottomView.backgroundColor = UIColor.whiteColor;
        _bottomView.hidden = YES;
        
        _readiconBtn = [[UIButton alloc]init];
        _readiconBtn.frame = CGRectMake(_bottomView.frame.size.width/2 - 20, _bottomView.frame.size.height/2 - 20, 40, 40);
        [_bottomView addSubview:_readiconBtn];
        [_readiconBtn setImageEdgeInsets:UIEdgeInsetsMake(8, 8, 8, 8)];
        [_readiconBtn setBackgroundColor:UIColor.clearColor];

        [_readiconBtn addTarget:self action:@selector(playBtnClick:) forControlEvents:UIControlEventTouchDown];
        
                
//        设置阴影
        self.clipsToBounds =NO;
        self.contentView.clipsToBounds =NO;
        
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 0);
        self.layer.shadowOpacity = 0.3;
        self.layer.shadowRadius = 5;
            
        NSLog(@" %f - %f - %f-%f",frame.size.width,frame.size.height,frame.origin.x,frame.origin.y);
                
        self.titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(self.frame.size.width/2 - 30, 20, 60, 30)];
        self.titleLabel.text = @"0";
        self.titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor colorWithRed:207/255.0 green:232/255.0 blue:240/255.0 alpha:1];
        self.titleLabel.layer.masksToBounds = YES;
        self.titleLabel.layer.cornerRadius = 15;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:self.titleLabel];
        


        self.discLabel = [[UILabel alloc]initWithFrame:CGRectMake(25, self.titleLabel.frame.size.height+self.titleLabel.frame.origin.y+30, frame.size.width - 50, 100)];
        [self.contentView addSubview:_discLabel];
        _discLabel.backgroundColor = UIColor.clearColor;
        self.discLabel.textAlignment = NSTextAlignmentCenter ;
        self.discLabel.lineBreakMode = NSLineBreakByTruncatingTail ;
        self.discLabel.numberOfLines = 0;
//        self.discLabel.
        [self.discLabel setValue:@(40) forKey:@"lineSpacing"];

        self.discLabel.textColor = UIColor.blackColor;

        self.discLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:24];
        [self.contentView bringSubviewToFront:_discLabel];
        

        
    }
    return self;
}

- (UICollectionViewLayoutAttributes *) preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super preferredLayoutAttributesFittingAttributes:layoutAttributes];
//    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    UICollectionViewLayoutAttributes *attributes = [layoutAttributes copy];
    CGSize size = [self.contentView systemLayoutSizeFittingSize: layoutAttributes.size];
    CGRect cellFrame = layoutAttributes.frame;
    cellFrame.size.height= size.height;
    attributes.size = cellFrame.size;
    
    if ( _bottomView.hidden == NO) {
        //绘制圆角 要设置的圆角 使用“|”来组合
        UIBezierPath *maskPath1 = [UIBezierPath bezierPathWithRoundedRect:_topView.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(15, 15)];
        CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
        //设置大小
        maskLayer.frame = _topView.bounds;
        //设置图形样子
        maskLayer.path = maskPath1.CGPath;
        _topView.layer.mask = maskLayer;
        
        UIBezierPath *maskPath2 = [UIBezierPath bezierPathWithRoundedRect:_bottomView.bounds byRoundingCorners:UIRectCornerBottomLeft | UIRectCornerBottomRight cornerRadii:CGSizeMake(15, 15)];
        maskLayer = [[CAShapeLayer alloc] init];
        //设置大小
        maskLayer.frame = _bottomView.bounds;
        //设置图形样子
        maskLayer.path = maskPath2.CGPath;
        _bottomView.layer.mask = maskLayer;
    }else{
        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:_topView.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight|UIRectCornerBottomLeft | UIRectCornerBottomRight cornerRadii:CGSizeMake(15, 15)];
        CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
        //设置大小
        maskLayer.frame = _topView.bounds;
        //设置图形样子
        maskLayer.path = maskPath.CGPath;
        _topView.layer.mask = maskLayer;
    }
    


    return attributes;
}
//设置不同字体颜色
-(void)addColorWithArray:(NSArray*)array
{
    
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:self.discLabel.text];
    for (NSString* str2 in array) {
        NSRange range1 = [self.discLabel.text rangeOfString:str2];//匹配得到的下标

        //设置字号
        [str addAttribute:NSFontAttributeName value:self.discLabel.font range:range1];
         
        //设置文字颜色
        [str addAttribute:NSForegroundColorAttributeName value:UIColor.redColor range:range1];
         
    }
    self.discLabel.attributedText = str;

}
-(void)playBtnClick:(UIButton*)sender{
    
}

-(void)startButtonAnimating{
    
   
}
-(void)stopButtonAnimating{
    NSLog(@"stopButtonAnimating");
    _btnPlaying = NO;
    [_readiconBtn.imageView stopAnimating];
    
}


@end
