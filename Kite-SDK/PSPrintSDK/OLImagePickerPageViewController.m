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

#import "OLImagePickerPageViewController.h"

@implementation OLImagePickerPageViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    
    UIButton *nextButton = [[UIButton alloc] init];
    self.nextButton = nextButton;
    [nextButton setTitle:NSLocalizedString(@"Next", @"") forState:UIControlStateNormal];
    [nextButton.titleLabel setFont:[UIFont systemFontOfSize:17]];
    [nextButton addTarget:self.imagePicker action:@selector(onButtonNextClicked:) forControlEvents:UIControlEventTouchUpInside];
    [nextButton setBackgroundColor:[UIColor colorWithRed:0.125 green:0.498 blue:0.655 alpha:1.000]];
    nextButton.hidden = YES;
    
    
    [self.view addSubview:nextButton];
    
    nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(nextButton);
    NSMutableArray *con = [[NSMutableArray alloc] init];
    
    NSArray *visuals = @[@"H:|-20-[nextButton]-20-|",
                         @"V:[nextButton(50)]-10-|"];
    
    
    for (NSString *visual in visuals) {
        [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
    }
    
    [nextButton.superview addConstraints:con];

}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    if (self.imagePicker.nextButton.hidden){
        self.nextButton.hidden = NO;
    }
    else{
        self.nextButton.hidden = YES;
    }
}

@end