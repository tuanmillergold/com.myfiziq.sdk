//
//  ViewModel.h
//  Prudential
//
//  Created by Jeames Gillett on 9/5/18.
//

#import <UIKit/UIKit.h>
@import MyFiziqSDK;

@interface ViewModel : UIViewController

@property (strong, nonatomic) UIViewController *rootCache;

- (BOOL)setAvatar:(MyFiziqAvatar *)avatar;

@end
