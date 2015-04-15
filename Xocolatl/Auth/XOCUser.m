//
//  XOCUser.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XOCUser.h"

#import <CommonCrypto/CommonDigest.h>
#import "NSString+randomString.h"

@interface XOCUser () <NSCoding>

@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy) NSData *password;
@property (nonatomic, copy) NSString *salt;

@end

@implementation XOCUser

+ (instancetype)newUserWithUsername:(NSString *)username
                        andPassword:(NSString *)password;
{
    //Create a new user.
    XOCUser *user = [[XOCUser alloc] init];
    user.username = username;
    user.salt = [NSString randomString];
    
    //Create a password.
    NSString *saltedPasswordString = [NSString stringWithFormat:@"%@%@", user.salt, password];
    NSData *saltedPasswordData = [saltedPasswordString dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *hashedPasswordData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(saltedPasswordData.bytes,
              (CC_LONG)saltedPasswordData.length,
              hashedPasswordData.mutableBytes);
    
    user.password = hashedPasswordData;
    user.identifier = [NSString stringWithFormat:@"%@%@", username, user.salt];
    
    return user;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder;
{
    if (self != [super init]) {
        return nil;
    }
    
    _identifier = [aDecoder decodeObjectForKey:@"identifier"];
    _username = [aDecoder decodeObjectForKey:@"username"];
    _password = [aDecoder decodeObjectForKey:@"password"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.username forKey:@"username"];
    [aCoder encodeObject:self.password forKey:@"password"];
}

@end
