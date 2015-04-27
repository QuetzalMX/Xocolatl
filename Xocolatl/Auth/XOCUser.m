//
//  XOCUser.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XOCUser.h"

#import "NSData+hashedPassword.h"
#import "NSString+randomString.h"

NSString *const XOCUserPasswordSalt = @"XOCUserPasswordSalt";

@interface XOCUser () <NSCoding>

@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy) NSData *password;
@property (nonatomic, strong) NSMutableDictionary *salts;
@property (nonatomic, strong) NSMutableDictionary *authorizations;

@end

@implementation XOCUser

+ (instancetype)newUserWithUsername:(NSString *)username;
{
    //Create a new user.
    XOCUser *user = [[self alloc] init];
    user.username = username;
    user.salts = [NSMutableDictionary new];
    user.authorizations = [NSMutableDictionary new];
    
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
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.username forKey:@"username"];
    [aCoder encodeObject:self.password forKey:@"password"];
}

- (NSDictionary *)jsonRepresentation;
{
    return @{@"id": self.identifier,
             @"username": self.username};
}

#pragma mark - Aurhotization
- (NSString *)addAuthHeaderWithSessionDuration:(NSTimeInterval)secondsUntilExpiration;
{
    if (secondsUntilExpiration <= 0) {
        return nil;
    }
    
    NSString *authExpiration = [NSString stringWithFormat:@"exp=%f", [[NSDate date] timeIntervalSince1970] + secondsUntilExpiration];
    NSString *authUsername = [NSString stringWithFormat:@"username=%@", self.username];
    NSString *clearAuthorization = [NSString stringWithFormat:@"%@&%@", authExpiration, authUsername];
    
    self.salts[clearAuthorization] = [NSString randomString];
    NSData *encryptedAuthData = [NSData SHA256passwordUsing:clearAuthorization
                                                   andSaltPrefix:self.salts[clearAuthorization]];
    
    return [clearAuthorization stringByAppendingFormat:@"&auth=%@", [encryptedAuthData SHA256String]];
}

#pragma mark - Password
+ (BOOL)verifyPasswordHashForUser:(XOCUser *)user
                     withPassword:(NSString *)password;
{
    NSData *proposedHashedPassword = [NSData SHA256passwordUsing:password
                                                   andSaltPrefix:user.salts[XOCUserPasswordSalt]];
    
    return [proposedHashedPassword isEqualTo:user.password];
}

- (void)setHashedPassword:(NSString *)password;
{
    self.salts[XOCUserPasswordSalt] = [NSString randomString];
    self.password = [NSData SHA256passwordUsing:password
                                  andSaltPrefix:self.salts[XOCUserPasswordSalt]];
    self.identifier = [NSString stringWithFormat:@"%@", [NSString randomString]];
}

@end