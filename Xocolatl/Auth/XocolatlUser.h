//
//  XOCUser.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlModelObject.h"

@interface XocolatlUser : XocolatlModelObject

@property (nonatomic, copy, readonly) NSString *username;

//Self
+ (instancetype)newUserWithUsername:(NSString *)username
                        andPassword:(NSString *)password;

//Passwords
+ (BOOL)verifyPasswordHashForUser:(XocolatlUser *)user
                     withPassword:(NSString *)password;

//Auth
- (NSString *)newAuthHeaderWithTimeOfDeath:(NSTimeInterval)secondsUntilExpiration;
- (BOOL)validateAuthHeader:(NSString *)clientProvidedAuth;

@end
