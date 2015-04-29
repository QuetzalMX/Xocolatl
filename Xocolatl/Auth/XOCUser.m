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

NSString *const UsersCollection = @"Users";
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
    _salts = [[aDecoder decodeObjectForKey:@"salts"] mutableCopy];
    _authorizations = [[aDecoder decodeObjectForKey:@"authorizations"] mutableCopy];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.username forKey:@"username"];
    [aCoder encodeObject:self.password forKey:@"password"];
    [aCoder encodeObject:self.salts forKey:@"salts"];
    [aCoder encodeObject:self.authorizations forKey:@"authorizations"];
}

- (NSDictionary *)jsonRepresentation;
{
    return @{@"id": self.identifier,
             @"username": self.username};
}

#pragma mark - Authorization
- (BOOL)isTimeOfDeathAfterNow:(NSTimeInterval)timeOfDeath;
{
    return [[NSDate date] timeIntervalSince1970] >= timeOfDeath;
}

- (NSString *)clearAuthorizationWithTimeOfDeath:(NSTimeInterval)timeOfDeath;
{
    //In order to make our cookie secure, we add an authorization string that uses SHA256 to digest the expiration and username.
    NSString *expiration = [NSString stringWithFormat:@"%.0f", timeOfDeath];
    NSString *username = [NSString stringWithFormat:@"%@", self.username];
    return [NSString stringWithFormat:@"%@%@", expiration, username];
}

- (NSString *)encryptedAuthoziationWithClearAuth:(NSString *)clearAuthorization
                                         andSalt:(NSString *)salt;
{
    NSData *encryptedAuthData = [NSData SHA256passwordUsing:clearAuthorization
                                              andSaltPrefix:self.salts[clearAuthorization]];
    return [encryptedAuthData SHA256String];
}

- (NSString *)newAuthHeaderWithTimeOfDeath:(NSTimeInterval)timeOfDeath;
{
    if ([self isTimeOfDeathAfterNow:timeOfDeath]) {
        return nil;
    }
    
    NSString *clearAuthorization = [self clearAuthorizationWithTimeOfDeath:timeOfDeath];
    self.salts[clearAuthorization] = [NSString randomString];
    return [self encryptedAuthoziationWithClearAuth:clearAuthorization
                                            andSalt:self.salts[clearAuthorization]];
}

- (BOOL)validateAuthHeader:(NSString *)clientProvidedAuth
           withTimeOfDeath:(NSTimeInterval)timeOfDeath;
{
    //Let's see if we can validate it.
    NSString *clearAuthorization = [self clearAuthorizationWithTimeOfDeath:timeOfDeath];
    NSString *saltForAuthorization = self.salts[clearAuthorization];
    if (!saltForAuthorization) {
        //We don't have a salt registered for this auth.
#warning This seems pretty bad. We're trying to validate an authorization we didn't send. Are we under attack?
        return NO;
    }
    
    //We have a salt registered for this timeOfDeath.
    NSString *serverValidatedAuth = [self encryptedAuthoziationWithClearAuth:clearAuthorization
                                                                     andSalt:saltForAuthorization];
    
    if (![serverValidatedAuth isEqualToString:clientProvidedAuth]) {
        //However, the encryption does not match.
        return NO;
    }
    
    //Okay, this token seems to be valid. Is it expired?
    if ([self isTimeOfDeathAfterNow:timeOfDeath]) {
        //This isn't valid anymore.
        return NO;
    }
    
    //It all checks. Let's go.
    return YES;
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