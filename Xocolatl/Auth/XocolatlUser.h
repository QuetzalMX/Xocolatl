//
//  XOCUser.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlModelObject.h"

@interface XocolatlUser : XocolatlModelObject

/**
 *  This token is optionally used to send push notifications.
 */
@property (nullable, nonatomic, copy) NSString *apnToken;

//Self
- (nullable instancetype)initWithUsername:(nonnull NSString *)username
                              andPassword:(nonnull NSString *)password;

//Passwords
+ (BOOL)verifyPasswordHashForUser:(nonnull XocolatlUser *)user
                     withPassword:(nonnull NSString *)password;

//Auth
- (nullable NSString *)newAuthHeaderWithDefaultExpiration;
- (nullable NSString *)newAuthHeaderWithTimeOfDeath:(NSTimeInterval)secondsUntilExpiration;
- (BOOL)validateAuthHeader:(nonnull NSString *)clientProvidedAuth;

@end
