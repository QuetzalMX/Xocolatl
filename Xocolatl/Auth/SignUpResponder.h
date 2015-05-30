//
//  SignUpRoute.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "DatabaseResponder.h"

#import "RoutingResponse.h"

@interface SignUpResponder : DatabaseResponder

@property (nonatomic) Class userClass;

- (instancetype)initWithReadConnection:(YapDatabaseConnection *)readConnection
                    andWriteConnection:(YapDatabaseConnection *)writeConnection
                              inServer:(XocolatlHTTPServer *)server
                         withUserClass:(Class)userClass;

- (void)willSaveUser:(XocolatlUser *)user
    usingRequestBody:(id)body;

@end

@interface RoutingResponse (SignUpResponder)

@property (nonatomic, strong) XocolatlUser *registeredUser;

@end