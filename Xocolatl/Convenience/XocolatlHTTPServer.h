//
//  XocolatlHTTPServer.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "RoutingHTTPServer.h"
#import "YapDatabase.h"
#import "DatabaseResponder.h"

@class SignUpResponder;

@interface XocolatlHTTPServer : RoutingHTTPServer

+ (instancetype)newServerNamed:(NSString *)name
               listeningAtPort:(NSInteger)port;

+ (instancetype)newServerNamed:(NSString *)name
               listeningAtPort:(NSInteger)port
     usingSSLCertificateAtPath:(NSString *)p12CertificatePath
        andCertificatePassword:(NSString *)certificatePassword;

@property (nonatomic, strong) YapDatabase *database;
@property (nonatomic, strong) YapDatabaseConnection *readConnection;
@property (nonatomic, strong) YapDatabaseConnection *writeConnection;

- (void)addDatabaseRoute:(Class)routeClass;
- (void)setSignUpRoute:(Class)signUpRouteClass
         withUserClass:(Class)userClass;

@end
