//
//  DatabaseResponder.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "RoutingResponder.h"
#import "YapDatabase.h"
#import "RoutingHTTPServer.h"

@class XOCUser;

@interface DatabaseResponder : RoutingResponder

@property (nonatomic, strong, readonly) RoutingHTTPServer *server;
@property (nonatomic, strong, readonly) YapDatabaseConnection *readConnection;
@property (nonatomic, strong, readonly) YapDatabaseConnection *writeConnection;
@property (nonatomic, strong, readonly) XOCUser *user;

- (instancetype)initWithReadConnection:(YapDatabaseConnection *)readConnection
                    andWriteConnection:(YapDatabaseConnection *)writeConnection
                              inServer:(RoutingHTTPServer *)server;

//Authentication
- (BOOL)isProtected:(NSString *)method;
- (BOOL)isRequestAuthenticated:(HTTPMessage *)request;
- (RoutingResponse *)handleAuthenticationFailure;

@end