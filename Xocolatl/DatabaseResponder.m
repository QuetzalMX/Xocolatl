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
    if ([self isProtected:message.method] && ![self isRequestAuthenticated:message]) {
        return [self handleAuthenticationFailure];
    }
    
    return [super responseForRequest:message
                      withParameters:parameters];
}

- (BOOL)isRequestAuthenticated:(HTTPMessage *)request;
{
    NSString *username = request.cookies[@"username"];
    NSString *auth = request.cookies[@"auth"];
    if (!username || username.length <= 0 ||
        !auth || auth.length <= 0) {
        //No user or authorization.
        return NO;
    }
    
    //There appears to be user, expiration and authorization. Is the auth valid?
    __block XOCUser *user;
    __block BOOL isValidAuth;
    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        user = [XOCUser objectWithIdentifier:username
                            usingTransaction:transaction];
        
        isValidAuth = [user validateAuthHeader:auth];
    }];

    //Save the user and affirm authorization.
    self.user = (isValidAuth) ? user : nil;
    
    return isValidAuth;
}

- (BOOL)isProtected:(NSString *)method;
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