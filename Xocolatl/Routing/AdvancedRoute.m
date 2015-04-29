//
//  AdvancedRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AdvancedRoute.h"
#import "YapDatabase.h"

@interface AdvancedRoute ()

@property (nonatomic, weak, readwrite) RoutingHTTPServer *server;
@property (nonatomic, strong, readwrite) YapDatabaseConnection *connection;

@end

@implementation AdvancedRoute

- (instancetype)initInServer:(RoutingHTTPServer *)server;
{
    if (self != [super init]) {
        return nil;
    }
    
    self.server = server;
    self.target = self;
    self.connection = [self.server.database newConnection];
    self.selector = @selector(incomingRequest:response:);
    
    return self;
}

- (void)incomingRequest:(RouteRequest *)request
               response:(RouteResponse *)response;
{
    //Implemented by subclasses.
}

@end
