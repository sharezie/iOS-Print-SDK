//
//  Modified MIT License
//
//  Copyright (c) 2010-2016 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The software MAY ONLY be used with the Kite Tech Ltd platform and MAY NOT be modified
//  to be used with any competitor platforms. This means the software MAY NOT be modified
//  to place orders with any competitors to Kite Tech Ltd, all orders MUST go through the
//  Kite Tech Ltd platform servers.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "OLImageEditViewController.h"
#import "OLPhotoTextField.h"
#import "OLColorSelectionCollectionViewCell.h"
#import "OLKiteUtils.h"
#import "UIImage+ImageNamedInKiteBundle.h"
#import "UIView+RoundRect.h"
#import "OLAsset+Private.h"
#import "OLUserSession.h"
#import "OLImagePickerViewController.h"
#import "OLNavigationController.h"
#import "OLProductTemplateOption.h"
#import "UIImage+ImageNamedInKiteBundle.h"

const NSInteger kOLEditTagImages = 10;
const NSInteger kOLEditTagProductOptionsTab = 20;
const NSInteger kOLEditTagImageTools = 30;
/**/const NSInteger kOLEditTagTextTools = 31;
/**/const NSInteger kOLEditTagTextColors = 32;
/**/const NSInteger kOLEditTagFonts = 33;
const NSInteger kOLEditTagCrop = 40;

@interface OLImageEditViewController () <RMImageCropperDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, OLPhotoTextFieldDelegate, OLImagePickerViewControllerDelegate>
@property (assign, nonatomic) NSInteger initialOrientation;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *centerYCon;

@property (strong, nonatomic) NSMutableArray<OLPhotoTextField *> *textFields;
@property (strong, nonatomic) UIVisualEffectView *visualEffectView;
@property (strong, nonatomic) UIVisualEffectView *visualEffectView2;
@property (strong, nonatomic) NSArray<UIColor *> *availableColors;
@property (strong, nonatomic) UIView *textFieldsView;
@property (strong, nonatomic) NSArray<NSString *> *fonts;
@property (assign, nonatomic) CGFloat textFieldKeyboardDiff;
@property (assign, nonatomic) BOOL resizingTextField;
@property (assign, nonatomic) BOOL rotatingTextField;

@property (strong, nonatomic) OLPhotoTextField *activeTextField;
@property (assign, nonatomic) CGFloat originalDrawerHeight;

@property (strong, nonatomic) IBOutletCollection(UIView) NSArray *allViews;
//@property (strong, nonatomic) IBOutletCollection(UIImageView) NSArray *cropFrameEdges;
@property (strong, nonatomic) NSMutableArray *cropFrameGuideViews;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cropViewTopCon;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cropViewLeftCon;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cropViewBottomCon;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cropViewRightCon;
@property (weak, nonatomic) IBOutlet UIView *printContainerView;
@property (weak, nonatomic) IBOutlet UINavigationBar *navigationBar;

@property (weak, nonatomic) OLProductTemplateOption *selectedOption;

@property (strong, nonatomic) UITextField *borderTextField;

@end

@implementation OLImageEditViewController

-(NSArray<NSString *> *) fonts{
    if (!_fonts){
        NSMutableArray<NSString *> *fonts = [[NSMutableArray<NSString *> alloc] init];
        for (NSString *familyName in [UIFont familyNames]){
            for (NSString *fontName in [UIFont fontNamesForFamilyName:familyName]) {
                [fonts addObject:fontName];
            }
        }
        [fonts addObject:NSLocalizedString(@"Default", @"")];
        _fonts = [fonts sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    return _fonts;
}

-(OLPhotoEdits *) edits{
    if (!_edits && self.asset){
        _edits = [self.asset.edits copy];
    }
    if (!_edits){
        _edits = [[OLPhotoEdits alloc] init];
    }
    return _edits;
}

-(NSMutableArray *) textFields{
    if (!_textFields){
        _textFields = [[NSMutableArray alloc] init];
    }
    return _textFields;
}

- (UIEdgeInsets)borderInsets{
    if (self.product){
        return self.product.productTemplate.imageBorder;
    }
    
    return _borderInsets;
}

- (void)setActiveTextField:(OLPhotoTextField *)activeTextField{
    if (activeTextField){
        if (self.editingTools.collectionView.tag != kOLEditTagTextTools && activeTextField != _activeTextField){ //Showing colors/fonts for another textField. Dismiss first
            [self dismissDrawerWithCompletionHandler:^(BOOL finished){
                self.editingTools.collectionView.tag = kOLEditTagTextTools;
                
                self.editingTools.drawerHeightCon.constant = self.originalDrawerHeight;
                [self.view layoutIfNeeded];
                
                [self.editingTools.collectionView reloadData];
                self.editingTools.collectionView.tag = kOLEditTagTextTools;
                [self showDrawerWithCompletionHandler:NULL];
            }];
        }
        else{
            self.editingTools.collectionView.tag = kOLEditTagTextTools;
            
            self.editingTools.drawerHeightCon.constant = self.originalDrawerHeight;
            [self.view layoutIfNeeded];
            
            [self.editingTools.collectionView reloadData];
            [self showDrawerWithCompletionHandler:NULL];
        }
    }
    else if (self.editingTools.collectionView.tag == kOLEditTagTextTools){
        [self dismissDrawerWithCompletionHandler:NULL];
    }
     _activeTextField = activeTextField;
}

- (void)onTapGestureRecognized:(id)sender{
    [self.borderTextField resignFirstResponder];
    
    for (OLPhotoTextField *textField in self.textFields){
        if ([textField isFirstResponder]){
            [textField resignFirstResponder];
            return;
        }
    }
    
    if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
        [self.activeTextField hideButtons];
    }
    self.activeTextField = nil;
    
    if (self.editingTools.collectionView.tag != kOLEditTagCrop){
    [self dismissDrawerWithCompletionHandler:NULL];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.navigationController){
        [self.navigationBar removeFromSuperview];
    }
    
    self.availableColors = @[[UIColor blackColor], [UIColor whiteColor], [UIColor darkGrayColor], [UIColor colorWithRed:0.890 green:0.863 blue:0.761 alpha:1.000], [UIColor colorWithRed:0.765 green:0.678 blue:0.588 alpha:1.000], [UIColor colorWithRed:0.624 green:0.620 blue:0.612 alpha:1.000], [UIColor colorWithRed:0.976 green:0.910 blue:0.933 alpha:1.000], [UIColor colorWithRed:0.604 green:0.522 blue:0.741 alpha:1.000], [UIColor colorWithRed:0.996 green:0.522 blue:0.886 alpha:1.000], [UIColor colorWithRed:0.392 green:0.271 blue:0.576 alpha:1.000], [UIColor colorWithRed:0.906 green:0.573 blue:0.565 alpha:1.000], [UIColor colorWithRed:0.984 green:0.275 blue:0.404 alpha:1.000], [UIColor colorWithRed:0.918 green:0.000 blue:0.200 alpha:1.000], [UIColor colorWithRed:0.776 green:0.176 blue:0.157 alpha:1.000], [UIColor colorWithRed:0.965 green:0.831 blue:0.239 alpha:1.000], [UIColor colorWithRed:0.961 green:0.682 blue:0.118 alpha:1.000], [UIColor colorWithRed:0.945 green:0.482 blue:0.204 alpha:1.000], [UIColor colorWithRed:0.827 green:0.859 blue:0.898 alpha:1.000], [UIColor colorWithRed:0.616 green:0.710 blue:0.851 alpha:1.000], [UIColor colorWithRed:0.400 green:0.541 blue:0.784 alpha:1.000], [UIColor colorWithRed:0.400 green:0.541 blue:0.784 alpha:1.000], [UIColor colorWithRed:0.173 green:0.365 blue:0.725 alpha:1.000], [UIColor colorWithRed:0.102 green:0.247 blue:0.361 alpha:1.000], [UIColor colorWithRed:0.765 green:0.933 blue:0.898 alpha:1.000], [UIColor colorWithRed:0.506 green:0.788 blue:0.643 alpha:1.000], [UIColor colorWithRed:0.345 green:0.502 blue:0.400 alpha:1.000], [UIColor colorWithRed:0.337 green:0.427 blue:0.208 alpha:1.000]];
    
    [self registerCollectionViewCells];
    self.editingTools.collectionView.dataSource = self;
    self.editingTools.collectionView.delegate = self;
    
    [self setupCropGuides];
    
    self.textFieldsView = [[UIView alloc] init];
    self.textFieldsView.userInteractionEnabled = NO;
    [self.view insertSubview:self.textFieldsView aboveSubview:self.cropView];
    self.textFieldsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.textFieldsView.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.textFieldsView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self.textFieldsView.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.textFieldsView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [self.textFieldsView.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.textFieldsView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [self.textFieldsView.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.textFieldsView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
    
    self.originalDrawerHeight = self.editingTools.drawerHeightCon.constant;
    
    if (self.previewView && !self.skipPresentAnimation){
        self.view.backgroundColor = [UIColor clearColor];
        self.previewView.alpha = 0.15;
        [self.view addSubview:self.previewView];
        [self.view sendSubviewToBack:self.previewView];
        for (UIView *view in self.allViews){
            view.alpha = 0;
        }
    }
    
    self.initialOrientation = self.fullImage.imageOrientation;
    self.cropView.delegate = self;
    
    if (self.forceSourceViewDimensions && self.previewSourceView){
        UIView *view = self.cropView;
        view.translatesAutoresizingMaskIntoConstraints = NO;
        NSDictionary *views = NSDictionaryOfVariableBindings(view);
        NSMutableArray *con = [[NSMutableArray alloc] init];
        
        NSArray *visuals = @[[NSString stringWithFormat:@"H:[view(%f)]", self.previewSourceView.frame.size.width]];
        
        
        for (NSString *visual in visuals) {
            [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
        }
        
        [view.superview addConstraints:con];

    }
    
    if (self.centerYConConstant){
        self.centerYCon.constant = [self.centerYConConstant integerValue];
    }
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] init];
    [tapGesture addTarget:self action:@selector(onTapGestureRecognized:)];
    [self.view addGestureRecognizer:tapGesture];
    
    NSArray *copy = [[NSArray alloc] initWithArray:self.edits.textsOnPhoto copyItems:NO];
    for (OLTextOnPhoto *textOnPhoto in copy){
        UITextField *textField = [self addTextFieldToView:self.cropView temp:NO];
        textField.text = textOnPhoto.text;
        textField.transform = textOnPhoto.transform;
        textField.textColor = textOnPhoto.color;
        textField.font = [OLKiteUtils fontWithName:textOnPhoto.fontName size:textOnPhoto.fontSize];
        [self.edits.textsOnPhoto removeObject:textOnPhoto];
    }
    
    [self registerForKeyboardNotifications];
    
    UIVisualEffect *blurEffect;
    blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    
    self.visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    UIView *view = self.visualEffectView;
    
    [self.editingTools.drawerView addSubview:view];
    [self.editingTools.drawerView sendSubviewToBack:view];
    
    view.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(view);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:|-0-[view]-0-|",
                         @"V:|-0-[view]-0-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [view.superview addConstraints:con];
    
    [self.view insertSubview:self.editingTools.drawerView belowSubview:self.editingTools];
    
    [self.editingTools.drawerView.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.editingTools.drawerView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.editingTools.drawerView.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.editingTools.drawerView.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.editingTools.drawerView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.editingTools.drawerView.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    [self.editingTools.drawerView.superview addConstraint:[NSLayoutConstraint constraintWithItem:self.editingTools.drawerView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.editingTools.drawerView.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    
    self.editingTools.drawerView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
    
    [self setupButtons];
    
    self.ctaButton = self.editingTools.ctaButton;
    self.ctaButton.enabled = NO;
    self.ctaButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.ctaButton.titleLabel.minimumScaleFactor = 0.5;
    
    self.cropView.clipsToBounds = YES;
    [self orderViews];
    
    self.printContainerView.backgroundColor = [self containerBackgroundColor];
    
    [self.cropView removeConstraint:self.aspectRatioConstraint];
    self.aspectRatioConstraint = [NSLayoutConstraint constraintWithItem:self.cropView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeWidth multiplier:self.aspectRatio constant:0];
    [self.cropView addConstraints:@[self.aspectRatioConstraint]];
}

- (void)setupCropGuides{
    self.cropFrameGuideViews = [[NSMutableArray alloc] init];
    
    UIImageView *cornerTL = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-corner-ul"]];
    [cornerTL setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [cornerTL setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.cropFrameGuideViews addObject:cornerTL];
    [self.printContainerView addSubview:cornerTL];
    [self.printContainerView sendSubviewToBack:cornerTL];
    cornerTL.translatesAutoresizingMaskIntoConstraints = NO;
    [cornerTL.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerTL attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTop multiplier:1 constant:-2]];
    [cornerTL.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerTL attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeLeading multiplier:1 constant:-2]];

    UIImageView *cornerTR = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-corner-ur"]];
    [cornerTR setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [cornerTR setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.cropFrameGuideViews addObject:cornerTR];
    [self.printContainerView addSubview:cornerTR];
    [self.printContainerView sendSubviewToBack:cornerTR];
    cornerTR.translatesAutoresizingMaskIntoConstraints = NO;
    [cornerTR.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerTR attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTop multiplier:1 constant:-2]];
    [cornerTR.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerTR attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTrailing multiplier:1 constant:2]];
    
    UIImageView *cornerBR = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-corner-dr"]];
    [cornerBR setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [cornerBR setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.cropFrameGuideViews addObject:cornerBR];
    [self.printContainerView addSubview:cornerBR];
    [self.printContainerView sendSubviewToBack:cornerBR];
    cornerBR.translatesAutoresizingMaskIntoConstraints = NO;
    [cornerBR.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerBR attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeBottom multiplier:1 constant:2]];
    [cornerBR.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerBR attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTrailing multiplier:1 constant:2]];
    
    UIImageView *cornerBL = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-corner-dl"]];
    [cornerBL setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [cornerBL setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.cropFrameGuideViews addObject:cornerBL];
    [self.printContainerView addSubview:cornerBL];
    [self.printContainerView sendSubviewToBack:cornerBL];
    cornerBL.translatesAutoresizingMaskIntoConstraints = NO;
    [cornerBL.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerBL attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeBottom multiplier:1 constant:2]];
    [cornerBL.superview addConstraint:[NSLayoutConstraint constraintWithItem:cornerBL attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeLeading multiplier:1 constant:-2]];
    
     UIImageView *lineLeft = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-line-left"]];
    [self.cropFrameGuideViews addObject:lineLeft];
    [self.printContainerView addSubview:lineLeft];
    [self.printContainerView sendSubviewToBack:lineLeft];
    lineLeft.translatesAutoresizingMaskIntoConstraints = NO;
    [lineLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineLeft attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5]];
    [lineLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineLeft attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeLeading multiplier:1 constant:-2]];
    [lineLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineLeft attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:cornerBL attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [lineLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineLeft attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:cornerTL attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    
    
    UIImageView *lineRight = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-line-right"]];
    [self.cropFrameGuideViews addObject:lineRight];
    [self.printContainerView addSubview:lineRight];
    [self.printContainerView sendSubviewToBack:lineRight];
    lineRight.translatesAutoresizingMaskIntoConstraints = NO;
    [lineRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineRight attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5]];
    [lineRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineRight attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTrailing multiplier:1 constant:2]];
    [lineRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineRight attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:cornerBR attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [lineRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineRight attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:cornerTR attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

    UIImageView *lineTop = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-line-up"]];
    [self.cropFrameGuideViews addObject:lineTop];
    [self.printContainerView addSubview:lineTop];
    [self.printContainerView sendSubviewToBack:lineTop];
    lineTop.translatesAutoresizingMaskIntoConstraints = NO;
    [lineTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineTop attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5]];
    [lineTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineTop attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTop multiplier:1 constant:-2]];
    [lineTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineTop attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:cornerTL attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    [lineTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineTop attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:cornerTR attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    UIImageView *lineBottom = [[UIImageView alloc] initWithImage:[UIImage imageNamedInKiteBundle:@"crop-line-down"]];
    [self.cropFrameGuideViews addObject:lineBottom];
    [self.printContainerView addSubview:lineBottom];
    [self.printContainerView sendSubviewToBack:lineBottom];
    lineBottom.translatesAutoresizingMaskIntoConstraints = NO;
    [lineBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineBottom attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:5]];
    [lineBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineBottom attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeBottom multiplier:1 constant:2]];
    [lineBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineBottom attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:cornerBL attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    [lineBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:lineBottom attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:cornerBR attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    UIView *darkViewTop = [[UIView alloc] init];
    darkViewTop.translatesAutoresizingMaskIntoConstraints = NO;
    darkViewTop.backgroundColor = [UIColor colorWithWhite:0.227 alpha:0.750];
    [self.view addSubview:darkViewTop];
    [self.view sendSubviewToBack:darkViewTop];
    [self.cropFrameGuideViews addObject:darkViewTop];
    [darkViewTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewTop attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.topLayoutGuide attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [darkViewTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewTop attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:darkViewTop.superview attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [darkViewTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewTop attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:darkViewTop.superview attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [darkViewTop.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewTop attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    
    UIView *darkViewLeft = [[UIView alloc] init];
    darkViewLeft.translatesAutoresizingMaskIntoConstraints = NO;
    darkViewLeft.backgroundColor = [UIColor colorWithWhite:0.227 alpha:0.750];
    [self.view addSubview:darkViewLeft];
    [self.view sendSubviewToBack:darkViewLeft];
    [self.cropFrameGuideViews addObject:darkViewLeft];
    [darkViewLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewLeft attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:darkViewTop attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [darkViewLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewLeft attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:darkViewLeft.superview attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [darkViewLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewLeft attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:darkViewLeft.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [darkViewLeft.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewLeft attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];

    UIView *darkViewRight = [[UIView alloc] init];
    darkViewRight.translatesAutoresizingMaskIntoConstraints = NO;
    darkViewRight.backgroundColor = [UIColor colorWithWhite:0.227 alpha:0.750];
    [self.view addSubview:darkViewRight];
    [self.view sendSubviewToBack:darkViewRight];
    [self.cropFrameGuideViews addObject:darkViewRight];
    [darkViewRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewRight attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:darkViewTop attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [darkViewRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewRight attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:darkViewRight.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [darkViewRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewRight attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:darkViewRight.superview attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [darkViewRight.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewRight attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];

    UIView *darkViewBottom = [[UIView alloc] init];
    darkViewBottom.translatesAutoresizingMaskIntoConstraints = NO;
    darkViewBottom.backgroundColor = [UIColor colorWithWhite:0.227 alpha:0.750];
    [self.view addSubview:darkViewBottom];
    [self.view sendSubviewToBack:darkViewBottom];
    [self.cropFrameGuideViews addObject:darkViewBottom];
    [darkViewBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewBottom attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.bottomLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [darkViewBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewBottom attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:darkViewLeft attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    [darkViewBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewBottom attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:darkViewRight attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [darkViewBottom.superview addConstraint:[NSLayoutConstraint constraintWithItem:darkViewBottom attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.cropView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    
    for (UIView *view in self.cropFrameGuideViews){
        view.alpha = 0;
    }
    
}

- (void)orderViews{
    [self.view bringSubviewToFront:self.printContainerView];
    [self.view bringSubviewToFront:self.cropView];
    [self.view bringSubviewToFront:self.previewView];
    [self.view bringSubviewToFront:self.editingTools.drawerView];
    [self.view bringSubviewToFront:self.editingTools];
}

- (UIColor *)containerBackgroundColor{
    return self.edits.borderColor ? self.edits.borderColor : [UIColor whiteColor];
}

- (BOOL)hasEditableBorder{
    return !UIEdgeInsetsEqualToEdgeInsets(self.borderInsets, UIEdgeInsetsZero);
}

- (UIEdgeInsets)imageInsetsOnContainer{
    UIEdgeInsets b = self.borderInsets;
    
    CGFloat width = self.printContainerView.frame.size.width;
    CGFloat height = (width * (1.0 - b.left - b.right)) * self.aspectRatio;
    height = height / (1 - b.top - b.bottom);
    
    return UIEdgeInsetsMake(b.top * height, b.left * width, b.bottom * height, b.right * width);
}

- (CGFloat)heightForButtons{
    return 64 + self.editingTools.drawerView.frame.size.height;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (self.previewView && !self.skipPresentAnimation){
        [UIView animateWithDuration:0.10 animations:^{
            self.previewView.alpha = 1;
        } completion:^(BOOL finished){
            self.previewSourceView.hidden = YES;
            [UIView animateWithDuration:0.25 animations:^{
                self.previewView.frame = self.printContainerView.frame;
            }completion:^(BOOL finished){
                [UIView animateWithDuration:0.25 animations:^{
                    self.view.backgroundColor = [UIColor colorWithWhite:0.227 alpha:1.000];
                    for (UIView *view in self.allViews){
                        view.alpha = 1;
                    }
                } completion:^(BOOL finished){
                    [self.previewView removeFromSuperview];
                }];
            }];
        }];
    }
}

- (void)setupImage{
    if (self.edits.counterClockwiseRotations > 0 || self.edits.flipHorizontal || self.edits.flipVertical){
        self.cropView.image = [UIImage imageWithCGImage:self.fullImage.CGImage scale:self.fullImage.scale orientation:[OLPhotoEdits orientationForNumberOfCounterClockwiseRotations:self.edits.counterClockwiseRotations andInitialOrientation:self.fullImage.imageOrientation horizontalFlip:self.edits.flipHorizontal verticalFlip:self.edits.flipVertical]];
    }
    else{
        [self.cropView setImage:self.fullImage];
    }
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    self.cropView.imageView.transform = self.edits.cropTransform;
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if (self.fullImage){
        [self setupImage];
    }
    else{
        [self loadImageFromAsset];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    self.cropView.imageView.image = nil;
    self.edits.cropImageRect = [self.cropView getImageRect];
    self.edits.cropImageFrame = [self.cropView getFrameRect];
    self.edits.cropImageSize = [self.cropView croppedImageSize];
    self.edits.cropTransform = [self.cropView.imageView transform];
    
    [coordinator animateAlongsideTransition:^(id context){
        [self setupImage];
        [self.editingTools.collectionView.collectionViewLayout invalidateLayout];
    }completion:^(id context){
        NSString *borderString = self.borderTextField.text;
        if (borderString){
            [self.borderTextField removeFromSuperview];
            self.borderTextField = nil;
            [self setupBottomBorderTextField];
            self.borderTextField.text = borderString;
        }
    }];
}

-(void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    if (self.enableCircleMask){
        CAShapeLayer *aCircle=[CAShapeLayer layer];
        aCircle.path=[UIBezierPath bezierPathWithRoundedRect:self.cropView.bounds cornerRadius:self.cropView.frame.size.height/2].CGPath;
        
        aCircle.fillColor=[UIColor blackColor].CGColor;
        self.cropView.layer.mask=aCircle;
    }
    
    UIEdgeInsets b = [self imageInsetsOnContainer];
    if (self.cropViewTopCon.constant != b.top || self.cropViewRightCon.constant != b.right || self.cropViewBottomCon.constant != b.bottom || self.cropViewLeftCon.constant != b.left){
        self.cropViewTopCon.constant = b.top;
        self.cropViewRightCon.constant = b.right;
        self.cropViewBottomCon.constant = b.bottom;
        self.cropViewLeftCon.constant = b.left;
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        self.cropView.imageView.transform = self.edits.cropTransform;
    }
}

- (void)setupBottomBorderTextField{
    if (self.borderInsets.bottom / self.borderInsets.top >= 1.1 && !self.borderTextField){
        UITextField *tf = [[UITextField alloc] init];
        tf.delegate = self;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.tintColor = self.editingTools.ctaButton.backgroundColor;
        tf.textAlignment = NSTextAlignmentCenter;
        tf.adjustsFontSizeToFitWidth = YES;
        tf.minimumFontSize = 1;
        tf.placeholder = @"Tap to Add Text";
        tf.font = [UIFont fontWithName:@"HelveticaNeue" size:35];
        tf.textColor = [UIColor blackColor];
        self.borderTextField = tf;
        
        [self.printContainerView addSubview:tf];
        
        UIView *cropView = self.cropView;
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        NSDictionary *views = NSDictionaryOfVariableBindings(tf, cropView);
        NSMutableArray *con = [[NSMutableArray alloc] init];
        
        UIEdgeInsets insets = [self imageInsetsOnContainer];
        
        NSArray *visuals = @[[NSString stringWithFormat:@"H:|-%f-[tf]-%f-|", insets.left - 5, insets.right - 5],
                             @"V:[cropView]-10-[tf(40)]"];
        
        
        for (NSString *visual in visuals) {
            [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
        }
        
        [tf.superview addConstraints:con];
    }
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion{
    if (!self.previewView){
        [super dismissViewControllerAnimated:flag completion:completion];
    }
    else if (!flag){
        [super dismissViewControllerAnimated:NO completion:completion];
    }
    else{
        [self exitCropMode];
        
        UIEdgeInsets b = [self imageInsetsOnContainer];
        [self.printContainerView addSubview:self.cropView];
        self.cropView.frame = CGRectMake(b.left, b.top, self.printContainerView.frame.size.width - b.left - b.right, self.printContainerView.frame.size.height - b.top - b.bottom);
        self.cropView.imageView.transform = self.edits.cropTransform;
        self.previewView  = [self.printContainerView snapshotViewAfterScreenUpdates:YES];
        
        self.previewView.frame = self.printContainerView.frame;
        [self.view addSubview:self.previewView];
        [UIView animateWithDuration:0.25 animations:^{
            self.view.backgroundColor = [UIColor clearColor];
            for (UIView *view in self.allViews){
                view.alpha = 0;
            }
        } completion:^(BOOL finished){
            [UIView animateWithDuration:0.25 animations:^{
                self.previewView.frame = [self.previewSourceView.superview convertRect:self.previewSourceView.frame toView:self.presentingViewController.view];
            }completion:^(BOOL finished){
                self.previewSourceView.hidden = NO;
                [UIView animateWithDuration:0.15 animations:^{
                    self.previewView.alpha = 0;
                } completion:^(BOOL finished){
                    [super dismissViewControllerAnimated:NO completion:completion];
                }];
                
            }];
        }];
    }
}

- (UITextField *)addTextFieldToView:(UIView *)view temp:(BOOL)temp{
    OLPhotoTextField *textField = [[OLPhotoTextField alloc] initWithFrame:CGRectMake(0, 0, 130, 70)];
    textField.center = self.cropView.center;
    textField.margins = 10;
    textField.delegate = self;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.photoTextFieldDelegate = self;
    textField.keyboardAppearance = UIKeyboardAppearanceDark;
    [textField addTarget:self
                  action:@selector(textFieldDidChange:)
        forControlEvents:UIControlEventEditingChanged];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] init];
    panGesture.delegate = self;
    [panGesture addTarget:self action:@selector(onTextfieldGesturePanRecognized:)];
    [textField addGestureRecognizer:panGesture];
    
    [view addSubview:textField];
    [textField.superview addConstraint:[NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:textField.superview attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [textField.superview addConstraint:[NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:textField.superview attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(textField);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:[textField(>=100)]",
                         @"V:[textField(>=40)]"];
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [textField.superview addConstraints:con];
    
    if (!temp){
        [self.textFields addObject:textField];
    }
    
    return textField;
}

- (CGFloat)angleOfTouchPoint:(CGPoint)p fromPoint:(CGPoint)c{
    CGFloat x = p.x - c.x;
    CGFloat y = p.y - c.y;

    if (y == 0){
        y = 0.000001; //Avoid division by zero, even though it produces the right result
    }
    
    CGFloat angle = atan(x / y);
    if (y >= 0){
        angle = angle + M_PI;
    }
    
    return -angle;
}

- (void)onTextfieldGesturePanRecognized:(UIPanGestureRecognizer *)gesture{
    static CGAffineTransform original;
    static CGFloat originalFontSize;
    static CGRect originalFrame;
    static CGFloat originalAngle;
    
    if (gesture.state == UIGestureRecognizerStateBegan){
        original = gesture.view.transform;
        originalFrame = gesture.view.frame;
        CGPoint gesturePoint = [gesture locationInView:self.cropView];
        CGPoint translatedPoint = CGPointMake(gesturePoint.x - original.tx, gesturePoint.y - original.ty);
        originalAngle = [self angleOfTouchPoint:translatedPoint fromPoint:gesture.view.center];
        
        
        
        OLPhotoTextField *textField = (OLPhotoTextField *)gesture.view;
        originalFontSize = textField.font.pointSize;
        
        if (self.activeTextField != textField){
            [self.activeTextField resignFirstResponder];
            if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
                [self.activeTextField hideButtons];
            }
            self.activeTextField = (OLPhotoTextField *)textField;
            if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
                [self.activeTextField showButtons];
            }
        }
    }
    else if (gesture.state == UIGestureRecognizerStateChanged){
        CGPoint translate = [gesture translationInView:gesture.view.superview];
        CGAffineTransform translation = CGAffineTransformTranslate(CGAffineTransformMakeTranslation(original.tx, original.ty), translate.x, translate.y);
        CGAffineTransform transform = original;
        transform.tx = translation.tx;
        transform.ty = translation.ty;
        
        if (self.resizingTextField){
            CGFloat sizeChange = sqrt(translate.x * translate.x + translate.y * translate.y);
            if (translate.x < 0 && translate.y < 0){
                sizeChange = -sizeChange;
            }
            else if (translate.x < 0){
                sizeChange = translate.y;
            }
            else if (translate.y < 0){
                sizeChange = translate.x;
            }
            OLPhotoTextField *textField = (OLPhotoTextField *)gesture.view;
            CGFloat fontSize = textField.font.pointSize;
            textField.font = [UIFont fontWithName:textField.font.fontName size:MAX(originalFontSize + sizeChange, 30)];
            [textField sizeToFit];
            if (textField.frame.origin.x < 0 || textField.frame.origin.y < 0 || textField.frame.origin.x + textField.frame.size.width > textField.superview.frame.size.width || textField.frame.origin.y + textField.frame.size.height > textField.superview.frame.size.height){
                textField.font = [UIFont fontWithName:textField.font.fontName size:fontSize];
                [textField sizeToFit];
            }
            [textField setNeedsDisplay];
        }
        else if (self.rotatingTextField){
            static CGFloat previousAngle;
            
            CGPoint gesturePoint = [gesture locationInView:self.cropView];
            CGPoint translatedPoint = CGPointMake(gesturePoint.x - original.tx, gesturePoint.y - original.ty);
            CGFloat angle = [self angleOfTouchPoint:translatedPoint fromPoint:gesture.view.center];
            CGFloat deltaAngle = angle - previousAngle;
            angle = deltaAngle + previousAngle;
            previousAngle = angle;
            CGAffineTransform transform = original;
            transform.tx = 0;
            transform.ty = 0;
            transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(original.tx, original.ty), angle + atan2(transform.b, transform.a) - originalAngle);
            
            gesture.view.transform = transform;
        }
        else{
            CGFloat minY = gesture.view.frame.size.height/2.0 - self.cropView.frame.size.height / 2.0;
            CGFloat maxY = -minY;
            CGFloat minX = gesture.view.frame.size.width/2.0 - self.cropView.frame.size.width / 2.0;
            CGFloat maxX = -minX;
            if (transform.ty < minY){
                transform.ty = minY;
            }
            if (transform.ty > maxY){
                transform.ty = maxY;
            }
            if (transform.tx < minX){
                transform.tx = minX;
            }
            if (transform.tx > maxX){
                transform.tx = maxX;
            }
            gesture.view.transform = transform;
        }
    }
    else if (gesture.state == UIGestureRecognizerStateEnded){
        self.resizingTextField = NO;
        self.rotatingTextField = NO;
    }
    
    self.ctaButton.enabled = YES;
}


- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Drawer

- (void)dismissDrawerWithCompletionHandler:(void(^)(BOOL finished))handler{
    self.selectedOption = nil;
    self.editingTools.button1.selected = NO;
    self.editingTools.button2.selected = NO;
    self.editingTools.button3.selected = NO;
    self.editingTools.button4.selected = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.editingTools.drawerView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished){
        self.editingTools.collectionView.tag = -1;
        [self.view bringSubviewToFront:self.editingTools];
        self.editingTools.drawerHeightCon.constant = self.originalDrawerHeight;
        [self.view layoutIfNeeded];
        if (handler){
            handler(finished);
        }
    }];
}

- (void)showDrawerWithCompletionHandler:(void(^)(BOOL finished))handler{
    if (self.editingTools.collectionView.tag == kOLEditTagTextTools){
        self.editingTools.drawerLabel.text = NSLocalizedStringFromTableInBundle(@"TEXT TOOLS", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"");
    }
    else if (self.editingTools.collectionView.tag == kOLEditTagTextColors){
        self.editingTools.drawerLabel.text = NSLocalizedStringFromTableInBundle(@"TEXT COLOUR", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"");
    }
    else if (self.editingTools.collectionView.tag == kOLEditTagFonts){
        self.editingTools.drawerLabel.text = NSLocalizedStringFromTableInBundle(@"FONTS", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"");
    }

    [UIView animateWithDuration:0.25 animations:^{
        self.editingTools.drawerView.transform = CGAffineTransformMakeTranslation(0, -self.editingTools.drawerView.frame.size.height);
    } completion:^(BOOL finished){
        if (handler){
            handler(finished);
        }
    }];
    
    for (UIButton *b in [self.editingTools buttons]){
        if (b.tag / 10 == self.editingTools.collectionView.tag / 10){
            b.selected = YES;
        }
    }
}

#pragma mark Buttons

- (void)setupButtons{
    [self.editingTools.ctaButton addTarget:self action:@selector(onButtonDoneTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.editingTools.button1 setImage:[UIImage imageNamedInKiteBundle:@"add-image-icon"] forState:UIControlStateNormal];
    self.editingTools.button1.tag = kOLEditTagImages;
    [self.editingTools.button1 addTarget:self action:@selector(onButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    if (self.product.productTemplate.options.count > 0){
        self.editingTools.button2.tag = kOLEditTagProductOptionsTab;
        [self.editingTools.button2 addTarget:self action:@selector(onButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.product.productTemplate.options.firstObject iconWithCompletionHandler:^(UIImage *icon){
            [self.editingTools.button2 setImage:icon forState:UIControlStateNormal];
        }];
    }
    else{
        [self.editingTools.button2 removeFromSuperview];
    }
    
    [self.editingTools.button3 setImage:[UIImage imageNamedInKiteBundle:@"tools-icon"] forState:UIControlStateNormal];
    self.editingTools.button3.tag = kOLEditTagImageTools;
    [self.editingTools.button3 addTarget:self action:@selector(onButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.editingTools.button4 setImage:[UIImage imageNamedInKiteBundle:@"crop"] forState:UIControlStateNormal];
    self.editingTools.button4.tag = kOLEditTagCrop;
     [self.editingTools.button4 addTarget:self action:@selector(onButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)saveEditsToAsset:(OLAsset *)asset{
    self.edits.cropImageRect = [self.cropView getImageRect];
    self.edits.cropImageFrame = [self.cropView getFrameRect];
    self.edits.cropImageSize = [self.cropView croppedImageSize];
    self.edits.cropTransform = [self.cropView.imageView transform];
    
    for (OLPhotoTextField *textField in self.textFields){
        if (!textField.text || [textField.text isEqualToString:@""]){
            continue;
        }
        OLTextOnPhoto *textOnPhoto = [[OLTextOnPhoto alloc] init];
        textOnPhoto.text = textField.text;
        textOnPhoto.frame = textField.frame;
        textOnPhoto.transform = textField.transform;
        textOnPhoto.color = textField.textColor;
        textOnPhoto.fontName = textField.font.fontName;
        textOnPhoto.fontSize = textField.font.pointSize;
        [self.edits.textsOnPhoto addObject:textOnPhoto];
    }
    
    if (asset){
        asset.edits = self.edits;
    }
    
    if (self.borderTextField.text){
        self.product.selectedOptions[@"polaroid_text"] = self.borderTextField.text;
    }
}

- (void)onButtonDoneTapped:(id)sender {
    [self saveEditsToAsset:nil];
    
    if (self.asset && [self.delegate respondsToSelector:@selector(scrollCropViewController:didReplaceAssetWithAsset:)]){
        [self.delegate scrollCropViewController:self didReplaceAssetWithAsset:self.asset];
    }
    if ([self.delegate respondsToSelector:@selector(scrollCropViewController:didFinishCroppingImage:)]){
        [self.delegate scrollCropViewController:self didFinishCroppingImage:[self.cropView editedImage]];
    }
    else{
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
}

- (void)onBarButtonCancelTapped:(UIBarButtonItem *)sender {
    if (self.ctaButton.enabled && self.previewView && [self.delegate respondsToSelector:@selector(scrollCropViewControllerDidDropChanges:)]){ //discard changes
        [self exitCropMode];
        self.previewSourceView.hidden = NO;
        
        CGAffineTransform t = [self.cropView.imageView transform];
        UIEdgeInsets b = [self imageInsetsOnContainer];
        [self.printContainerView addSubview:self.cropView];
        self.cropView.frame = CGRectMake(b.left, b.top, self.printContainerView.frame.size.width - b.left - b.right, self.previewView.frame.size.height - b.top - b.bottom);
        self.cropView.imageView.transform = t;
        self.previewView  = [self.printContainerView snapshotViewAfterScreenUpdates:YES];
        
        self.previewView.frame = self.printContainerView.frame;
        [self.view addSubview:self.previewView];
        [UIView animateWithDuration:0.25 animations:^{
            self.view.backgroundColor = [UIColor clearColor];
            for (UIView *view in self.allViews){
                view.alpha = 0;
            }
        } completion:^(BOOL finished){
            [UIView animateWithDuration:0.7 animations:^{
                self.previewView.transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(0, self.view.frame.size.height), -M_PI_4);
            }completion:^(BOOL finished){
                if ([self.delegate respondsToSelector:@selector(scrollCropViewControllerDidDropChanges:)]){
                    [self.delegate scrollCropViewControllerDidDropChanges:self];
                }
                else{
                    [self dismissViewControllerAnimated:NO completion:NULL];
                }
            }];
        }];
    }
    else if ([self.delegate respondsToSelector:@selector(scrollCropViewControllerDidCancel:)]){
        [self.delegate scrollCropViewControllerDidCancel:self];
    }
    else{
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
}

- (void)selectButton:(UIButton *)sender{
    self.editingTools.collectionView.tag = sender.tag;
    
    switch (sender.tag) {
        case kOLEditTagImageTools:
            self.editingTools.drawerLabel.text = NSLocalizedStringFromTableInBundle(@"IMAGE TOOLS", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"");
            break;
        case kOLEditTagImages:
            [self showImagePicker];
            return;
        case kOLEditTagProductOptionsTab:
            if (self.product.productTemplate.options.count == 1){
                self.selectedOption = self.product.productTemplate.options.firstObject;
                self.editingTools.drawerLabel.text = [self.selectedOption.name uppercaseString];
                self.editingTools.collectionView.tag = self.selectedOption.type;
            }
            else{
                self.editingTools.drawerLabel.text = NSLocalizedStringFromTableInBundle(@"PRODUCT OPTIONS", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"");
            }

            break;
        case kOLEditTagCrop:
            [self onButtonCropClicked:sender];
            return;
            
        default:
            break;
    }
    
    sender.selected = YES;
    [self.editingTools.collectionView reloadData];
    
    [self showDrawerWithCompletionHandler:NULL];
}

- (void)deselectButton:(UIButton *)sender withCompletionHandler:(void (^)())handler{
    sender.selected = NO;
    [self dismissDrawerWithCompletionHandler:^(BOOL finished){
        if (handler){
            handler();
        }
    }];
}

- (void)deselectSelectedButtonWithCompletionHandler:(void (^)())handler{
    for (UIButton *button in [self.editingTools buttons]){
        if (button.selected){
            if (button.tag == kOLEditTagCrop){
                [self exitCropMode];
            }
            [self deselectButton:button withCompletionHandler:handler];
            break; //We should never have more than one selected button
        }
    }
}

- (void)onButtonClicked:(UIButton *)sender {
    void (^buttonAction)() = ^void(){
        [self selectButton:sender];
    };
    
    // Nothing is selected: just action
    if (!self.editingTools.button1.selected && !self.editingTools.button2.selected && !self.editingTools.button3.selected && !self.editingTools.button4.selected){
        buttonAction();
    }
    // Sender is selected but we're showing a 2nd or 3rd level drawer: return to 1st level
    else if (sender.selected && (self.editingTools.collectionView.tag == kOLEditTagTextTools || self.editingTools.collectionView.tag == kOLEditTagFonts || self.editingTools.collectionView.tag == kOLEditTagTextColors || (self.selectedOption && self.product.productTemplate.options.count != 1))){
        [self deselectSelectedButtonWithCompletionHandler:^(){
            buttonAction();
        }];
    }
    // Sender is selected: just deselect
    else if (sender.selected){
        [self deselectSelectedButtonWithCompletionHandler:NULL];
    }
    // Other is selected: Deselect and action
    else{
        [self deselectSelectedButtonWithCompletionHandler:^{
            buttonAction();
        }];
    }
}

#pragma mark Actions

- (IBAction)onButtonHorizontalFlipClicked:(id)sender {
    if (self.cropView.isCorrecting){
        return;
    }
    
    [self.activeTextField resignFirstResponder];
    if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
        [self.activeTextField hideButtons];
    }
    self.activeTextField = nil;
    
    [self.edits performHorizontalFlipEditFromOrientation:self.cropView.imageView.image.imageOrientation];
    
    [UIView transitionWithView:self.cropView.imageView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromRight animations:^{
        
        [self.cropView setImage:[UIImage imageWithCGImage:self.fullImage.CGImage scale:self.cropView.imageView.image.scale orientation:[OLPhotoEdits orientationForNumberOfCounterClockwiseRotations:self.edits.counterClockwiseRotations andInitialOrientation:self.initialOrientation horizontalFlip:self.edits.flipHorizontal verticalFlip:self.edits.flipVertical]]];
        
    }completion:NULL];
    
    self.ctaButton.enabled = YES;
}

- (IBAction)onButtonRotateClicked:(id)sender {
    if (self.cropView.isCorrecting){
        return;
    }
    
    [self.activeTextField resignFirstResponder];
    if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
        [self.activeTextField hideButtons];
    }
    self.activeTextField = nil;
    
    for (UITextField *textField in self.textFields){
        UITextField *textFieldCopy = [self addTextFieldToView:self.textFieldsView temp:YES];
        textFieldCopy.text = textField.text;
        textFieldCopy.transform = textField.transform;
        textFieldCopy.textColor = textField.textColor;
        textFieldCopy.font = textField.font;
        textField.hidden = YES;
    }
    
    [(UIBarButtonItem *)sender setEnabled:NO];
    self.edits.counterClockwiseRotations = (self.edits.counterClockwiseRotations + 1) % 4;
    CGAffineTransform transform = self.cropView.imageView.transform;
    transform.tx = self.cropView.imageView.transform.ty;
    transform.ty = -self.cropView.imageView.transform.tx;
    
    CGRect cropboxRect = self.cropView.frame;
    
    UIImage *newImage = [UIImage imageWithCGImage:self.fullImage.CGImage scale:self.cropView.imageView.image.scale orientation:[OLPhotoEdits orientationForNumberOfCounterClockwiseRotations:self.edits.counterClockwiseRotations andInitialOrientation:self.initialOrientation horizontalFlip:self.edits.flipHorizontal verticalFlip:self.edits.flipVertical]];
    CGFloat imageAspectRatio = newImage.size.height/newImage.size.width;
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.cropView.transform = CGAffineTransformMakeRotation(-M_PI_2);
        
        CGFloat boxWidth = self.cropView.frame.size.width;
        CGFloat boxHeight = self.cropView.frame.size.height;
        
        CGFloat imageWidth;
        CGFloat imageHeight;
        
        if (imageAspectRatio > 1.0){
            imageHeight = boxHeight;
            imageWidth = boxHeight * imageAspectRatio;
        }
        else{
            imageWidth = boxWidth;
            imageHeight = boxWidth / imageAspectRatio;
        }
        
        self.cropView.imageView.frame = CGRectMake((boxHeight - imageWidth)/ 2.0, (boxWidth - imageHeight) / 2.0, imageWidth, imageHeight);
        
    } completion:^(BOOL finished){
        for (UITextField *textField in self.textFields){
            textField.hidden = NO;
        }
        for (UITextField *textField in [self.textFieldsView.subviews copy]){
            [textField removeFromSuperview];
        }
        
        self.cropView.transform = CGAffineTransformIdentity;
        self.cropView.frame = cropboxRect;
        [self.cropView setImage:newImage];
        
        [(UIBarButtonItem *)sender setEnabled:YES];
        self.ctaButton.enabled = YES;
    }];
}

- (void)onButtonAddTextClicked:(UIButton *)sender {
    UITextField *textField = [self addTextFieldToView:self.cropView temp:NO];
    [self.view layoutIfNeeded];
    [textField becomeFirstResponder]; //Take focus away from any existing active TF
    [textField becomeFirstResponder]; //Become first responder
    
    self.ctaButton.enabled = YES;
}

- (void)onButtonCropClicked:(UIButton *)sender{
    for (UIView *view in self.cropFrameGuideViews){
        [self.printContainerView bringSubviewToFront:view];
    }
    sender.selected = YES;
    [UIView animateWithDuration:0.2 animations:^{
        for (UIView *view in self.cropFrameGuideViews){
            view.alpha = 1;
            [view.superview bringSubviewToFront:view];
        }
        [self.view bringSubviewToFront:self.editingTools];
        [self.view bringSubviewToFront:self.navigationBar];
    } completion:^(BOOL finished){
        self.cropView.clipsToBounds = NO;
        [self.view sendSubviewToBack:self.cropView];
    }];
}

- (void)exitCropMode{
    self.cropView.clipsToBounds = YES;
    [self orderViews];
    for (UIView *view in self.cropFrameGuideViews){
        [self.printContainerView bringSubviewToFront:view];
    }
    [UIView animateWithDuration:0.2 animations:^{
        for (UIView *view in self.cropFrameGuideViews){
            view.alpha = 0;
        }
    } completion:^(BOOL finished){
    }];
}

- (IBAction)onDrawerButtonDoneClicked:(UIButton *)sender {
    [self dismissDrawerWithCompletionHandler:^(BOOL finished){
        self.editingTools.collectionView.tag = kOLEditTagTextTools;
        
        self.editingTools.drawerHeightCon.constant = self.originalDrawerHeight;
        [self.view layoutIfNeeded];
        
        [self.editingTools.collectionView reloadData];
        [self showDrawerWithCompletionHandler:NULL];
    }];
}

#pragma mark CollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if (collectionView.tag == kOLEditTagTextTools){
        return 2;
    }
    else if (collectionView.tag == kOLEditTagProductOptionsTab){
        if (self.product.productTemplate.options.count == 1){
            return self.product.productTemplate.options.firstObject.choices.count;
        }
        else{
            return self.product.productTemplate.options.count;
        }
    }
    else if (collectionView.tag == kOLEditTagTextColors){
        return self.availableColors.count;
    }
    else if (collectionView.tag == kOLEditTagFonts){
        return self.fonts.count;
    }
    else if (collectionView.tag == kOLEditTagImageTools){
        return 3;
    }
    
    return self.selectedOption.choices.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell;
    if (collectionView.tag == kOLEditTagTextTools){
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"toolCell" forIndexPath:indexPath];
        [self setupToolCell:cell];
        
        if (indexPath.item == 0){
            [(UIImageView *)[cell viewWithTag:10] setImage:[UIImage imageNamedInKiteBundle:@"Aa"]];
            [(UILabel *)[cell viewWithTag:20] setText:NSLocalizedString(@"Fonts", @"")];
        }
        else if (indexPath.item == 1){
            [(UIImageView *)[cell viewWithTag:10] setImage:[UIImage imageNamedInKiteBundle:@"paint-bucket-icon"]];
            [(UILabel *)[cell viewWithTag:20] setText:NSLocalizedString(@"Text Colour", @"")];
        }
    }
    else if (collectionView.tag == kOLEditTagImageTools){
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"toolCell" forIndexPath:indexPath];
        [self setupToolCell:cell];
        
        if (indexPath.item == 0){
            [(UIImageView *)[cell viewWithTag:10] setImage:[UIImage imageNamedInKiteBundle:@"flip"]];
            [(UILabel *)[cell viewWithTag:20] setText:NSLocalizedStringFromTableInBundle(@"Flip", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"")];
        }
        else if (indexPath.item == 1){
            [(UIImageView *)[cell viewWithTag:10] setImage:[UIImage imageNamedInKiteBundle:@"rotate"]];
            [(UILabel *)[cell viewWithTag:20] setText:NSLocalizedStringFromTableInBundle(@"Rotate", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"")];
        }
        else if (indexPath.item == 2){
            [(UIImageView *)[cell viewWithTag:10] setImage:[UIImage imageNamedInKiteBundle:@"Tt"]];
            [(UILabel *)[cell viewWithTag:20] setText:NSLocalizedStringFromTableInBundle(@"Add Text", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"")];
        }
    }
    else if (collectionView.tag == kOLEditTagTextColors || collectionView.tag == OLProductTemplateOptionTypeColor1 || collectionView.tag == OLProductTemplateOptionTypeColor2 || collectionView.tag == OLProductTemplateOptionTypeColor3){
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"colorSelectionCell" forIndexPath:indexPath];
        
        [cell setSelected:NO];
        for (UITextField *textField in self.textFields){
            if ([textField isFirstResponder]){
                [cell setSelected:[textField.textColor isEqual:self.availableColors[indexPath.item]]];
                break;
            }
        }
        
        [(OLColorSelectionCollectionViewCell *)cell setColor:self.availableColors[indexPath.item]];
        
        if (collectionView.tag == kOLEditTagTextColors){
            [cell setSelected:[self.activeTextField.textColor isEqual:self.availableColors[indexPath.item]]];
        }
        else if(collectionView.tag == OLProductTemplateOptionTypeColor1){
            [cell setSelected:[self.edits.borderColor isEqual:self.availableColors[indexPath.item]]];
        }
        //TODO color2,color3
        
        [cell setNeedsDisplay];
    }
    else if (collectionView.tag == kOLEditTagProductOptionsTab){
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"toolCell" forIndexPath:indexPath];
        [self setupToolCell:cell];
        
        OLProductTemplateOption *option = self.product.productTemplate.options[indexPath.item];
        [option iconWithCompletionHandler:^(UIImage *image){
            [(UIImageView *)[cell viewWithTag:10] setImage:image];
        }];
        [(UILabel *)[cell viewWithTag:20] setText:option.name];
    }
    else if (collectionView.tag == OLProductTemplateOptionTypeGeneric){
        OLProductTemplateOptionChoice *choice = self.selectedOption.choices[indexPath.item];
        __block UIImage *fallbackIcon;
        [choice iconWithCompletionHandler:^(UIImage *image){ //Fallback image returns syncronously
            fallbackIcon = image;
        }];
        if (choice.extraCost){
            cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"labelCell" forIndexPath:indexPath];
            [self setupLabelCell:cell];
            
            [(UILabel *)[cell viewWithTag:20] setNumberOfLines:2];
            [(UILabel *)[cell viewWithTag:20] setText:[NSString stringWithFormat:@"%@\n%@", choice.name, choice.extraCost]];
        }
        else if (choice.iconImageName || choice.iconURL || fallbackIcon){
            cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"toolCell" forIndexPath:indexPath];
            [self setupToolCell:cell];
            
            [choice iconWithCompletionHandler:^(UIImage *image){
                [(UIImageView *)[cell viewWithTag:10] setImage:image];
            }];
            [(UILabel *)[cell viewWithTag:20] setText:choice.name];
        }
        else{
            cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"labelCell" forIndexPath:indexPath];
            [self setupLabelCell:cell];
            
            [(UILabel *)[cell viewWithTag:10] setText:choice.name];
        }
        
        if (self.selectedOption.type == OLProductTemplateOptionTypeGeneric){
            [(OLButtonCollectionViewCell *)cell setSelectable:YES];
        }
        [cell setSelected:[self.product.selectedOptions[self.selectedOption.code] isEqualToString:choice.code]];
    }
    else if (collectionView.tag == kOLEditTagFonts){
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"fontCell" forIndexPath:indexPath];
        [self setupLabelCell:cell];
        UILabel *label = [cell viewWithTag:10];
        [label makeRoundRectWithRadius:4];
        label.text = self.fonts[indexPath.item];
        label.font = [OLKiteUtils fontWithName:label.text size:17];
        if ([self.activeTextField.font.fontName isEqualToString:label.text]){
            label.backgroundColor = [UIColor colorWithRed:0.349 green:0.757 blue:0.890 alpha:1.000];
        }
        else{
            label.backgroundColor = [UIColor clearColor];
        }
        label.textColor = [UIColor blackColor];
    }
    cell.clipsToBounds = NO;
    return cell;
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    if(collectionView.tag == kOLEditTagTextColors || collectionView.tag == OLProductTemplateOptionTypeColor1 || collectionView.tag == OLProductTemplateOptionTypeColor2 || collectionView.tag == OLProductTemplateOptionTypeColor3){
        return 25;
    }
    else{
        return 10;
    }
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    if (collectionView.tag == kOLEditTagFonts){
        return 0;
    }
    else if (collectionView.tag == kOLEditTagTextTools || collectionView.tag == kOLEditTagImageTools){
        return 10;
    }
    
    return 25;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    if (collectionView.tag == kOLEditTagTextColors || collectionView.tag == OLProductTemplateOptionTypeColor1 || collectionView.tag == OLProductTemplateOptionTypeColor2 || collectionView.tag == OLProductTemplateOptionTypeColor3){
        return CGSizeMake(self.editingTools.collectionView.frame.size.height, self.editingTools.collectionView.frame.size.height);
    }
    else if (collectionView.tag == kOLEditTagFonts){
        return CGSizeMake(collectionView.frame.size.width - 40, 30);
    }
    
    return CGSizeMake(self.editingTools.collectionView.frame.size.height * 1.5, self.editingTools.collectionView.frame.size.height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    if (collectionView.tag == kOLEditTagTextColors || collectionView.tag == OLProductTemplateOptionTypeColor1 || collectionView.tag == OLProductTemplateOptionTypeColor2 || collectionView.tag == OLProductTemplateOptionTypeColor3){
        return UIEdgeInsetsMake(0, 5, 0, 5);
    }
    
    CGFloat margin = MAX((collectionView.frame.size.width - ([self collectionView:collectionView layout:collectionView.collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:section]].width * [self collectionView:collectionView numberOfItemsInSection:section] + [self collectionView:collectionView layout:collectionViewLayout minimumLineSpacingForSectionAtIndex:section] * ([self collectionView:collectionView numberOfItemsInSection:section]-1)))/2.0, 5);
    return UIEdgeInsetsMake(0, margin, 0, margin);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if (collectionView.tag == kOLEditTagTextTools){
        if (indexPath.item == 0){
            [self dismissDrawerWithCompletionHandler:^(BOOL finished){
                [self.editingTools bringSubviewToFront:self.editingTools.drawerView];
                collectionView.tag = kOLEditTagFonts;
                
                self.editingTools.drawerHeightCon.constant = self.originalDrawerHeight + 150;
                [self.view layoutIfNeeded];
                [(UICollectionViewFlowLayout *)self.editingTools.collectionView.collectionViewLayout setScrollDirection:UICollectionViewScrollDirectionVertical];
                
                [collectionView reloadData];
                [self showDrawerWithCompletionHandler:NULL];
            }];
        }
        else if (indexPath.item == 1){
            [self dismissDrawerWithCompletionHandler:^(BOOL finished){
                [self.editingTools bringSubviewToFront:self.editingTools.drawerView];
                collectionView.tag = kOLEditTagTextColors;
                [(UICollectionViewFlowLayout *)self.editingTools.collectionView.collectionViewLayout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
                [collectionView reloadData];
                [self showDrawerWithCompletionHandler:NULL];
            }];
        }
        
    }
    else if (collectionView.tag == kOLEditTagImageTools){
        if (indexPath.item == 0){
            [self onButtonHorizontalFlipClicked:nil];
        }
        else if (indexPath.item == 1){
            [self onButtonRotateClicked:nil];
        }
        else if (indexPath.item == 2){
            [self onButtonAddTextClicked:nil];
        }
    }
    else if (collectionView.tag == OLProductTemplateOptionTypeColor1 || collectionView.tag == OLProductTemplateOptionTypeColor2 || collectionView.tag == OLProductTemplateOptionTypeColor3){
        self.printContainerView.backgroundColor = self.availableColors[indexPath.item];
        self.edits.borderColor = self.availableColors[indexPath.item];
        self.ctaButton.enabled = YES;
        [collectionView reloadData];
    }
    else if (collectionView.tag == kOLEditTagTextColors){
        [self.activeTextField setTextColor:self.availableColors[indexPath.item]];
        self.ctaButton.enabled = YES;
        [collectionView reloadData];
    }
    else if (collectionView.tag == kOLEditTagFonts){
        [self.activeTextField setFont:[OLKiteUtils fontWithName:self.fonts[indexPath.item] size:self.activeTextField.font.pointSize]];
        if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
            [self.activeTextField updateSize];
        }
        self.ctaButton.enabled = YES;
        [collectionView reloadData];
    }
    else if (self.selectedOption){
        self.product.selectedOptions[self.selectedOption.code] = self.selectedOption.choices[indexPath.item].code;
        
        for (NSIndexPath *visibleIndexPath in [collectionView indexPathsForVisibleItems]){
            if (![visibleIndexPath isEqual:indexPath]){
                [collectionView cellForItemAtIndexPath:visibleIndexPath].selected = NO;
            }
        }
    }
}

- (void)registerCollectionViewCells{
    [self.editingTools.collectionView registerClass:[OLButtonCollectionViewCell class] forCellWithReuseIdentifier:@"fontCell"];
    [self.editingTools.collectionView registerClass:[OLButtonCollectionViewCell class] forCellWithReuseIdentifier:@"iconCell"];
    [self.editingTools.collectionView registerClass:[OLButtonCollectionViewCell class] forCellWithReuseIdentifier:@"toolCell"];
    [self.editingTools.collectionView registerClass:[OLButtonCollectionViewCell class] forCellWithReuseIdentifier:@"labelCell"];
    [self.editingTools.collectionView registerClass:[OLColorSelectionCollectionViewCell class] forCellWithReuseIdentifier:@"colorSelectionCell"];
}

- (void)setupLabelCell:(UICollectionViewCell *)cell{
    UILabel *label = [[UILabel alloc] init];
    label.tag = 10;
    label.font = [UIFont systemFontOfSize:17];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.3;
    if ([label respondsToSelector:@selector(setAllowsDefaultTighteningForTruncation:)]){
        label.allowsDefaultTighteningForTruncation = YES;
    }
    
    [cell.contentView addSubview:label];
    
    label.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(label);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:|-0-[label]-0-|",
                         @"V:|-0-[label]-0-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [label.superview addConstraints:con];
}

- (void)setupToolCell:(UICollectionViewCell *)cell{
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.contentMode = UIViewContentModeCenter;
    imageView.tag = 10;
    imageView.tintColor = [UIColor blackColor];
    
    UILabel *label = [[UILabel alloc] init];
    label.tag = 20;
    label.font = [UIFont systemFontOfSize:12];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    [label setTextColor:[UIColor blackColor]];
    if ([label respondsToSelector:@selector(setAllowsDefaultTighteningForTruncation:)]){
        label.allowsDefaultTighteningForTruncation = YES;
    }
    
    [cell.contentView addSubview:imageView];
    [cell.contentView addSubview:label];
    
    label.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(label, imageView);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:|-0-[imageView]-0-|", @"H:|-0-[label]-0-|",
                         @"V:|-0-[imageView(20)]-5-[label]-0-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [label.superview addConstraints:con];
}

- (void)setupImageCell:(UICollectionViewCell *)cell{
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.contentMode = UIViewContentModeCenter;
    imageView.tag = 10;
    imageView.tintColor = [UIColor blackColor];
    
    [cell.contentView addSubview:imageView];
    
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(imageView);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:|-0-[imageView]-0-|", @"H:|-0-[label]-0-|",
                         @"V:|-0-[imageView(20)]-3-[label]-0-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [imageView.superview addConstraints:con];
}

- (void)setupIconCell:(UICollectionViewCell *)cell{
    
}

#pragma mark Keyboard Notifications

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification{
    NSDictionary *info = [aNotification userInfo];
    NSNumber *durationNumber = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curveNumber = [info objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    [UIView animateWithDuration:[durationNumber doubleValue] delay:0 options:[curveNumber unsignedIntegerValue] animations:^{
        [self.view layoutIfNeeded];
        
        if ([self.borderTextField isFirstResponder]){
            self.printContainerView.transform = CGAffineTransformIdentity;
            self.textFieldKeyboardDiff = 0;
        }
        else{
            for (UITextField *textField in self.textFields){
                if ([textField isFirstResponder]){
                    self.printContainerView.transform = CGAffineTransformIdentity;
                    self.textFieldKeyboardDiff = 0;
                    break;
                }
            }
        }
    }completion:NULL];
}

- (void)keyboardWillChangeFrame:(NSNotification*)aNotification{
    NSDictionary *info = [aNotification userInfo];
    CGFloat keyboardHeight = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    NSNumber *durationNumber = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curveNumber = [info objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    if ([self.borderTextField isFirstResponder]){
        CGPoint p = [self.printContainerView convertRect:self.borderTextField.frame toView:nil].origin;
        
        CGFloat diff = p.y + self.borderTextField.frame.size.height - (self.view.frame.size.height - keyboardHeight);
        if (diff > 0) {
            self.printContainerView.transform = CGAffineTransformMakeTranslation(0, -diff);
            self.textFieldKeyboardDiff = diff;
        }
    }
    else{
        for (UITextField *textField in self.textFields){
            if ([textField isFirstResponder]){
                CGPoint p = [self.cropView convertRect:textField.frame toView:nil].origin;
                
                CGFloat diff = p.y + textField.frame.size.height - (self.view.frame.size.height - keyboardHeight);
                if (diff > 0) {
                    self.printContainerView.transform = CGAffineTransformMakeTranslation(0, -diff);
                    self.textFieldKeyboardDiff = diff;
                }
                
                break;
            }
        }
    }
    
    [UIView animateWithDuration:[durationNumber doubleValue] delay:0 options:[curveNumber unsignedIntegerValue] animations:^{
        [self.view layoutIfNeeded];
    }completion:NULL];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]){
        otherGestureRecognizer.enabled = NO;
        otherGestureRecognizer.enabled = YES;
    }
    
    return NO;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidChange:(UITextField *)textField{
    if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
        [(OLPhotoTextField *)textField updateSize];
    }
    
    self.ctaButton.enabled = YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField{
    if ([textField isKindOfClass:[OLPhotoTextField class]]){
        [(OLPhotoTextField *)textField updateSize];
    }
    [textField setNeedsLayout];
    [textField layoutIfNeeded];
    
    //Remove empty textfield
    if ((!textField.text || [textField.text isEqualToString:@""]) && [textField isKindOfClass:[OLPhotoTextField class]]){
        [textField removeFromSuperview];
        [self.textFields removeObjectIdenticalTo:(OLPhotoTextField *)textField];
        self.activeTextField = nil;
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{
    if (textField == self.borderTextField){
        [self dismissDrawerWithCompletionHandler:NULL];
        return YES;
    }
    
    if (self.activeTextField == textField){
        if (self.editingTools.collectionView.tag == kOLEditTagFonts){
            [self dismissDrawerWithCompletionHandler:^(BOOL finished){
                self.editingTools.collectionView.tag = kOLEditTagTextTools;
                
                self.editingTools.drawerHeightCon.constant = self.originalDrawerHeight;
                [self.view layoutIfNeeded];
                
                [self.editingTools.collectionView reloadData];
                [self showDrawerWithCompletionHandler:NULL];
            }];
        }
        if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
            [(OLPhotoTextField *)textField updateSize];
        }
        return YES;
    }
    [self.activeTextField resignFirstResponder];
    if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
        [self.activeTextField hideButtons];
    }
    self.activeTextField = (OLPhotoTextField *)textField;
    if ([self.activeTextField isKindOfClass:[OLPhotoTextField class]]){
        [self.activeTextField showButtons];
    }
    return NO;
}

- (void)photoTextFieldDidSendActionTouchUpInsideForX:(OLPhotoTextField *)textField{
    [textField removeFromSuperview];
    [self.textFields removeObjectIdenticalTo:textField];
    self.activeTextField = nil;
}

- (void)photoTextFieldDidSendActionTouchDownForResize:(OLPhotoTextField *)textField{
    self.resizingTextField = YES;
}

- (void)photoTextFieldDidSendActionTouchUpForResize:(OLPhotoTextField *)textField{
    self.resizingTextField = NO;
}

- (void)photoTextFieldDidSendActionTouchDownForRotate:(OLPhotoTextField *)textField{
    self.rotatingTextField = YES;
}

- (void)photoTextFieldDidSendActionTouchUpForRotate:(OLPhotoTextField *)textField{
    self.rotatingTextField = NO;
}

#pragma mark - RMImageCropperDelegate methods

- (void)imageCropperDidTransformImage:(RMImageCropper *)imageCropper {
    self.ctaButton.enabled = YES;
}

#pragma mark Image Picker

- (void)showImagePicker{
    OLImagePickerViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"OLImagePickerViewController"];
    vc.delegate = self;
    vc.selectedAssets = [[NSMutableArray alloc] init];
    vc.maximumPhotos = 1;
    [self presentViewController:[[OLNavigationController alloc] initWithRootViewController:vc] animated:YES completion:NULL];
}

- (void)imagePickerDidCancel:(OLImagePickerViewController *)vc{
    [vc dismissViewControllerAnimated:YES completion:NULL];
}

- (void)imagePicker:(OLImagePickerViewController *)vc didFinishPickingAssets:(NSMutableArray *)assets added:(NSArray<OLAsset *> *)addedAssets removed:(NSArray *)removedAssets{
    self.asset = addedAssets.lastObject;
    self.edits = [self.asset.edits copy];
    if (self.asset){
        if ([self.delegate respondsToSelector:@selector(scrollCropViewController:didReplaceAssetWithAsset:)]){
            [self.delegate scrollCropViewController:self didReplaceAssetWithAsset:self.asset];
        }
        
        self.ctaButton.enabled = YES;
        id view = [self.view viewWithTag:1010];
        if ([view isKindOfClass:[UIActivityIndicatorView class]]){
            [(UIActivityIndicatorView *)view startAnimating];
        }
        
        for (UITextField *tf in self.textFields){
            [tf removeFromSuperview];
        }
        [self.textFields removeAllObjects];
        
        [self loadImageFromAsset];
    }
    
    [vc dismissViewControllerAnimated:YES completion:NULL];
}

- (void)loadImageFromAsset{
    __weak OLImageEditViewController *welf = self;
    [self.asset imageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:^(float progress){
        dispatch_async(dispatch_get_main_queue(), ^{
            [welf.cropView setProgress:progress];
        });
    } completion:^(UIImage *image){
        dispatch_async(dispatch_get_main_queue(), ^{
            welf.fullImage = image;
            
            NSArray *copy = [[NSArray alloc] initWithArray:welf.edits.textsOnPhoto copyItems:NO];
            for (OLTextOnPhoto *textOnPhoto in copy){
                UITextField *textField = [welf addTextFieldToView:welf.cropView temp:NO];
                textField.text = textOnPhoto.text;
                textField.transform = textOnPhoto.transform;
                textField.textColor = textOnPhoto.color;
                textField.font = [OLKiteUtils fontWithName:textOnPhoto.fontName size:textOnPhoto.fontSize];
                [self.edits.textsOnPhoto removeObject:textOnPhoto];
            }
            
            [welf setupImage];
            
            id view = [welf.view viewWithTag:1010];
            if ([view isKindOfClass:[UIActivityIndicatorView class]]){
                [(UIActivityIndicatorView *)view stopAnimating];
            }
        });
    }];
}

@end