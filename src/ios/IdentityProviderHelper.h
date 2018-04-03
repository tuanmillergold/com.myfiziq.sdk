//
//  MyFiziq-Boilerplate
//
//  Copyright (c) 2018 MyFiziq. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

/*
 OPTIONAL: The following helper class provides an example integration using the AWS Cognito User Pool idP service. This
 could alternatively use Facebook, Google, or any other idP service for user authentication. MyFiziq uses AWS Cognito
 Federated Identity Pool service to authorize an authenticated user to use the MyFiziq service, with the expectation that
 the account has been configured for the idP service. This example uses the AWS Cognito User Pool idP that is conveniently
 provided by the MyFiziq service and can be used in production.
 */

#import <Foundation/Foundation.h>
@import AWSCore;                    // NOTE: AWS service imports are required to authorize the user access.
@import AWSCognito;
@import AWSCognitoIdentityProvider;

#define EXAMPLE_APP_NAME    "MyFiziq-Example"

typedef NS_ENUM(NSUInteger, kAuthValidation) {
    kAuthValidationNoEmail,
    kAuthValidationInvalidEmail,
    kAuthValidationNoPassword,
    kAuthValidationPasswordTooShort,
    kAuthValidationPasswordsNotEqual,
    kAuthValidationIsValid
};


@interface IdentityProviderHelper : NSObject

/*
 NOTE: The AWS User Pool is used as an example idP, but Facebook and/or Google or other idP can easily be used.
 */
@property (strong, nonatomic) AWSServiceConfiguration *awsServiceConfiguration;
@property (strong, nonatomic) AWSCognitoIdentityUserPoolConfiguration *awsUserPoolConfig;
@property (strong, nonatomic) AWSCognitoIdentityUserPool *awsUserPool;
@property (readonly, nonatomic) AWSCognitoIdentityUser *currentUser;

+ (instancetype)shared;
- (BOOL)userIsSignedIn;
- (kAuthValidation)validateEmail:(NSString *)email passwordA:(NSString *)passA passwordB:(NSString *)passB;
- (void)userLoginWithEmail:(NSString *)email password:(NSString *)pass completion:(void (^)(NSError *err))completion;
- (void)userRegistrationWithEmail:(NSString *)email password:(NSString *)pass completion:(void (^)(NSError *err))completion;
- (void)userPasswordResetRequestWithEmail:(NSString *)email completion:(void (^)(NSError *err))completion;
- (void)userPasswordResetConfirmWithEmail:(NSString *)email resetCode:(NSString *)code newPassword:(NSString *)pass completion:(void (^)(NSError *err))completion;
- (AWSTask *)userReauthenticate;
- (void)userLogoutWithCompletion:(void (^)(NSError *err))completion;
- (void)userSetAWSCognitoLoginTokens:(AWSTaskCompletionSource<NSDictionary *> *)tokens;
- (NSString *) analyticsGetFirstTimeOrReturnUserCategoryExCreatedAvatar;

@end

