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
    //Where are we routing this request?
    if ([request.method isEqualToString:@"GET"] && self.methods[@"GET"]) {
        [self getRequest:request
                response:response];
    } else if ([request.method isEqualToString:@"POST"] && self.methods[@"POST"]) {
        [self postRequest:request
                 response:response];
    } else if ([request.method isEqualToString:@"PUT"] && self.methods[@"PUT"]) {
        [self putRequest:request
                response:response];
    } else if ([request.method isEqualToString:@"DELETE"] && self.methods[@"DELETE"]) {
        [self deleteRequest:request
                   response:response];
    }
}

- (void)getRequest:(RouteRequest *)request
          response:(RouteResponse *)response;
{
    //Implemented by subclasses.
}

- (void)postRequest:(RouteRequest *)request
           response:(RouteResponse *)response;
{
    //Implemented by subclasses.
}

- (void)putRequest:(RouteRequest *)request
          response:(RouteResponse *)response;
{
    //Implemented by subclasses.
}

- (void)deleteRequest:(RouteRequest *)request
             response:(RouteResponse *)response;
{
    //Implemented by subclasses.
}

@end
