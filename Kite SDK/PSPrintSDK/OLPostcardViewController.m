//
//  OLPostcardViewController.m
//  KitePrintSDK
//
//  Created by Konstadinos Karayannis on 4/7/15.
//  Copyright (c) 2015 Deon Botha. All rights reserved.
//

#import "OLPostcardViewController.h"

@interface OLSingleImageProductReviewViewController (Private)

@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet RMImageCropper *imageCropView;

@end

@interface OLPostcardViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *shadowView;
@property (strong, nonatomic) UIView *postcardBackView;
@property (assign, nonatomic) BOOL showingBack;

@end

@implementation OLPostcardViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    self.postcardBackView = [[NSBundle mainBundle] loadNibNamed:@"PostcardBackView" owner:nil options:nil].firstObject;
    self.postcardBackView.backgroundColor = [UIColor blackColor];
    [self.containerView addSubview:self.postcardBackView];
    self.postcardBackView.hidden = YES;
}

- (void)viewDidLayoutSubviews{
    self.postcardBackView.frame = self.imageCropView.frame;
}

- (IBAction)onButtonTurnClicked:(UIButton *)sender {
    [UIView transitionWithView:self.containerView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromRight animations:^{
        if (self.showingBack){
            self.showingBack = NO;
            self.postcardBackView.hidden = YES;
        }
        else{
            self.showingBack = YES;
            self.postcardBackView.hidden = NO;
        }
    }completion:NULL];
}

@end
