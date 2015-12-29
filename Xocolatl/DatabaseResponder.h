//
//  DatabaseResponder.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "RoutingResponder.h"

#import "HTTPVerbs.h"

@class YapDatabaseConnection;
@class XocolatlHTTPServer;
@class XocolatlUser;

@interface DatabaseResponder : RoutingResponder

@property (nonnull, nonatomic, strong, readonly) XocolatlHTTPServer *server;
@property (nonnull, nonatomic, strong, readonly) YapDatabaseConnection *readConnection;
@property (nonnull, nonatomic, strong, readonly) YapDatabaseConnection *writeConnection;
@property (nullable, nonatomic, strong, readonly) XocolatlUser *user;

- (nonnull instancetype)initWithReadConnection:(nonnull YapDatabaseConnection *)readConnection
                            andWriteConnection:(nonnull YapDatabaseConnection *)writeConnection
                                      inServer:(nonnull XocolatlHTTPServer *)server;

//Authentication
- (BOOL)isProtected:(nonnull NSString *)method;
- (BOOL)isRequestAuthenticated:(nonnull HTTPMessage *)request;
- (nonnull RoutingResponse *)handleAuthenticationFailure;

@end