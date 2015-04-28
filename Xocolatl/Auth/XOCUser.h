//
//  XOCUser.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XOCUser : NSObject <NSCoding>

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *username;

//Self
+ (instancetype)newUserWithUsername:(NSString *)username;
- (NSDictionary *)jsonRepresentation;

//Passwords
+ (BOOL)verifyPasswordHashForUser:(XOCUser *)user
                     withPassword:(NSString *)password;
- (void)setHashedPassword:(NSString *)password;

//Auth
- (NSString *)newAuthHeaderWithSessionDuration:(NSTimeInterval)secondsUntilExpiration;

@end
