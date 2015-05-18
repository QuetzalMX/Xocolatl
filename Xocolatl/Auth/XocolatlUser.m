//
//  XOCUser.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlUser.h"

#import "NSString+randomString.h"
#import "YapDatabase.h"

//Thanks Rob Napier.
#import "RNEncryptor.h"
#import "RNDecryptor.h"
#import "NSData+RNSecureCompare.h"

@interface XocolatlUser ()

@property (nonatomic, strong, readwrite) NSDate *modifiedAt;
@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy) NSData *password;
@property (nonatomic, strong) NSMutableSet *cookiePasswords;
@property (nonatomic, strong) NSMutableDictionary *authorizations;

@end

@implementation XocolatlUser

@synthesize modifiedAt;

+ (NSString *)yapDatabaseCollectionIdentifier;
{
    return @"XOCUserDatabaseCollectionIdentifier";
}

+ (instancetype)newUserWithUsername:(NSString *)username
                        andPassword:(NSString *)password;
{
    //Create a new user.
    XocolatlUser *user = [[self alloc] init];
    user.username = username;
    user.cookiePasswords = [NSMutableSet new];
    user.authorizations = [NSMutableDictionary new];
    
    NSError *error;
    user.password = [RNEncryptor encryptData:[username dataUsingEncoding:NSUTF8StringEncoding]
                                withSettings:kRNCryptorAES256Settings
                                    password:password
                                       error:&error];
    if (error) {
        return nil;
    }
    
    return user;
}

+ (instancetype)objectWithIdentifier:(NSString *)identifier
                    usingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    return [transaction objectForKey:identifier
                        inCollection:[XocolatlUser yapDatabaseCollectionIdentifier]];
}

- (void)saveUsingTransaction:(YapDatabaseReadWriteTransaction *)transaction;
{
    [transaction setObject:self
                    forKey:self.username
              inCollection:[XocolatlUser yapDatabaseCollectionIdentifier]];
    
    self.modifiedAt = [NSDate date];
}

#pragma mark - Serialization
- (instancetype)initWithCoder:(NSCoder *)aDecoder;
{
    if (self != [super initWithCoder:aDecoder]) {
        return nil;
    }
    
    _username = [aDecoder decodeObjectForKey:@"username"];
    _password = [aDecoder decodeObjectForKey:@"password"];
    _cookiePasswords = [[aDecoder decodeObjectForKey:@"cookiePasswords"] mutableCopy];
    _authorizations = [[aDecoder decodeObjectForKey:@"authorizations"] mutableCopy];
    _apnToken = [aDecoder decodeObjectForKey:@"apnToken"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.username forKey:@"username"];
    [aCoder encodeObject:self.password forKey:@"password"];
    [aCoder encodeObject:self.cookiePasswords forKey:@"cookiePasswords"];
    [aCoder encodeObject:self.authorizations forKey:@"authorizations"];
    [aCoder encodeObject:self.apnToken forKey:@"apnToken"];
}

- (NSDictionary *)jsonRepresentationUsingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    NSMutableDictionary *json = [[super jsonRepresentationUsingTransaction:transaction] mutableCopy];
    json[@"username"] = self.username;
    return json;
}

#pragma mark - Authorization
- (BOOL)isTimeOfDeathInTheFuture:(NSTimeInterval)timeOfDeath;
{
    return [[NSDate date] timeIntervalSince1970] < timeOfDeath;
}

- (NSString *)clearAuthorizationWithTimeOfDeath:(NSTimeInterval)timeOfDeath;
{
    //In order to make our cookie secure, we add an authorization string that uses SHA256 to digest the expiration and username.
    NSString *expiration = [NSString stringWithFormat:@"%.0f", timeOfDeath];
    NSString *username = [NSString stringWithFormat:@"%@", self.username];
    return [NSString stringWithFormat:@"%@%@", expiration, username];
}

- (NSString *)newAuthHeaderWithTimeOfDeath:(NSTimeInterval)timeOfDeath;
{
    if (![self isTimeOfDeathInTheFuture:timeOfDeath]) {
        return nil;
    }
    
    //Create a new cookie password and use it to encrypt the uesrname and timeOfDeath.
    NSString *passwordForAuthHeader = [NSString randomString];
    [self.cookiePasswords addObject:passwordForAuthHeader];

    NSString *clearText = [NSString stringWithFormat:@"%@:%.0f", self.username, timeOfDeath];
    NSError *error;
    NSData *cypherText = [RNEncryptor encryptData:[clearText dataUsingEncoding:NSUTF8StringEncoding]
                                     withSettings:kRNCryptorAES256Settings
                                         password:passwordForAuthHeader
                                            error:&error];

    if (error) {
        //Something went terribly wrong.
        [self.cookiePasswords removeObject:passwordForAuthHeader];
        return nil;
    }
    
    return [[cypherText base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)validateAuthHeader:(NSString *)clientProvidedAuth;
{
    NSString *urlDecodedClientProvidedAuth = [clientProvidedAuth stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSData *clientProvidedAuthData = [[NSData alloc] initWithBase64EncodedString:urlDecodedClientProvidedAuth
                                                                         options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    //Try decrypting the clientProvidedAuthData using our cookiePasswords.
    for (NSString *cookiePassword in self.cookiePasswords) {
        NSError *error;
        NSData *clearTextData = [RNDecryptor decryptData:clientProvidedAuthData
                                            withPassword:cookiePassword
                                                   error:&error];
        if (error) {
            continue;
        }
        
        NSString *clearText = [[NSString alloc] initWithData:clearTextData
                                                    encoding:NSUTF8StringEncoding];
        
        NSArray *clearTextComponents = [clearText componentsSeparatedByString:@":"];
        NSString *username = clearTextComponents.firstObject;
        NSString *timeToDeath = clearTextComponents.lastObject;
        if ([username isEqualToString:self.username]) {
            //This authHeader seems to be valid. What about expiration?
            return [self isTimeOfDeathInTheFuture:timeToDeath.floatValue];
        }
    }
    
    return NO;
}

#pragma mark - Password
+ (BOOL)verifyPasswordHashForUser:(XocolatlUser *)user
                     withPassword:(NSString *)password;
{
    //Check if the password can decrypt our hash.
    NSError *error;
    NSData *decryptedData = [RNDecryptor decryptData:user.password
                                        withPassword:password
                                               error:&error];
    
    if (error) {
        //It cannot. Wrong password for user.
        return NO;
    }
    
    //It can. Check against the username.
    return ([decryptedData rnsc_isEqualInConsistentTime:[user.username dataUsingEncoding:NSUTF8StringEncoding]]);
}

@end