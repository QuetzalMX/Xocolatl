//
//  DatabaseResponder.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "DatabaseResponder.h"

#import "RoutingResponse.h"
#import "XOCUser+Auth.h"

@interface DatabaseResponder ()

@property (nonatomic, strong, readwrite) XOCUser *user;
@property (nonatomic, strong, readwrite) RoutingHTTPServer *server;
@property (nonatomic, strong, readwrite) YapDatabaseConnection *readConnection;
@property (nonatomic, strong, readwrite) YapDatabaseConnection *writeConnection;

@end

@implementation DatabaseResponder

- (instancetype)initWithReadConnection:(YapDatabaseConnection *)readConnection
                    andWriteConnection:(YapDatabaseConnection *)writeConnection
                              inServer:(RoutingHTTPServer *)server;
{
    if (self != [super init]) {
        return nil;
    }
    
    //Make sure our connections are read and readwrite.
    _readConnection = readConnection;
    _readConnection.permittedTransactions = YDB_AnyReadTransaction;
    
    _writeConnection = writeConnection;
    _writeConnection.permittedTransactions = YDB_AnyReadWriteTransaction;
    
    _server = server;
    
    return self;
}

#pragma mark - Authentication
- (RoutingResponse *)responseForRequest:(HTTPMessage *)message
                         withParameters:(NSDictionary *)parameters;
{
    if (self.isProtected && ![self isRequestAuthenticated:message]) {
        return [self handleAuthenticationFailure];
    }
    
    return [super responseForRequest:message
                      withParameters:parameters];
}

- (BOOL)isRequestAuthenticated:(HTTPMessage *)request;
{
    //Parse the cookies to see if we have an authorized user.
    NSString *cookie = request.allHeaderFields[@"cookie"];
    NSString *cookieWithoutSemiColons = [cookie stringByReplacingOccurrencesOfString:@";"
                                                                          withString:@""];
    NSArray *subCookies = [cookieWithoutSemiColons componentsSeparatedByString:@" "];
    
    NSMutableDictionary *parsedCookies = [NSMutableDictionary new];
    for (NSString *subCookie in subCookies) {
        NSArray *cookieFieldAndValue = [subCookie componentsSeparatedByString:@"="];
        if (cookieFieldAndValue.count < 2) {
            continue;
        }
        
        parsedCookies[cookieFieldAndValue.firstObject] = cookieFieldAndValue.lastObject;
    }
    
    NSString *username = parsedCookies[@"username"];
    NSString *auth = parsedCookies[@"auth"];
    NSString *expiration = parsedCookies[@"timeOfDeath"];
    if (!username || username.length <= 0 ||
        !auth || auth.length <= 0 ||
        !expiration || expiration.length <= 0) {
        //No user or authorization.
        return NO;
    }
    
    //There appears to be user, expiration and authorization. Is the auth valid?
    __block XOCUser *user;
    __block BOOL isValidAuth;
    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        user = [transaction objectForKey:username
                            inCollection:UsersCollection];
        
        isValidAuth = [user validateAuthHeader:auth
                               withTimeOfDeath:expiration.integerValue];
    }];

    //Save the user and affirm authorization.
    self.user = (isValidAuth) ? user : nil;
    
    return isValidAuth;
}

- (BOOL)isProtected;
{
    return NO;
}

- (RoutingResponse *)handleAuthenticationFailure;
{
    return [RoutingResponse responseWithError:[NSError errorWithDomain:@"Authentication Failure"
                                                                  code:401
                                                              userInfo:@{@"reason": @"You are not authorized."}]];
}

@end