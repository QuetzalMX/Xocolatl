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
    if ([request.method isEqualToString:HTTPMethodGET] && self.methods[HTTPMethodGET]) {
        [self getRequest:request
                response:response];
    } else if ([request.method isEqualToString:HTTPMethodPOST] && self.methods[HTTPMethodPOST]) {
        [self postRequest:request
                 response:response];
    } else if ([request.method isEqualToString:HTTPMethodPUT] && self.methods[HTTPMethodPUT]) {
        [self putRequest:request
                response:response];
    } else if ([request.method isEqualToString:HTTPMethodDELETE] && self.methods[HTTPMethodDELETE]) {
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
