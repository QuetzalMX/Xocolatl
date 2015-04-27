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

@interface XOCUser ()

@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy) NSData *password;
@property (nonatomic, copy) NSString *salt;

@end

@implementation XOCUser

+ (instancetype)newUserWithUsername:(NSString *)username;
{
    //Create a new user.
    XOCUser *user = [[self alloc] init];
    user.username = username;
    
    return user;
}

#pragma mark - Serialization
- (instancetype)initWithCoder:(NSCoder *)aDecoder;
{
    if (self != [super init]) {
        return nil;
    }
    
    _identifier = [aDecoder decodeObjectForKey:@"identifier"];
    _username = [aDecoder decodeObjectForKey:@"username"];
    _password = [aDecoder decodeObjectForKey:@"password"];
    _salt = [aDecoder decodeObjectForKey:@"salt"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.username forKey:@"username"];
    [aCoder encodeObject:self.password forKey:@"password"];
    [aCoder encodeObject:self.salt forKey:@"salt"];
}

- (NSDictionary *)jsonRepresentation;
{
    return @{@"id": self.identifier,
             @"username": self.username};
}

#pragma mark - Password
+ (NSData *)hashedPassword:(NSString *)password
                   usingSalt:(NSString *)salt;
{
    //Create a password.
    NSString *saltedPasswordString = [NSString stringWithFormat:@"%@%@", salt, password];
    NSData *saltedPasswordData = [saltedPasswordString dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *hashedPasswordData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(saltedPasswordData.bytes,
              (CC_LONG)saltedPasswordData.length,
              hashedPasswordData.mutableBytes);
    
    return hashedPasswordData;
}

+ (BOOL)verifyPasswordHashForUser:(XOCUser *)user
                     withPassword:(NSString *)password;
{
    NSData *proposedHashedPassword = [XOCUser hashedPassword:password
                                                   usingSalt:user.salt];
    
    return [proposedHashedPassword isEqualTo:user.password];
}

- (void)setHashedPassword:(NSString *)password;
{
    self.salt = [NSString randomString];
    self.password = [XOCUser hashedPassword:password
                                  usingSalt:self.salt];
    self.identifier = [NSString stringWithFormat:@"%@", [NSString randomString]];
}

@end