//
//  AdvancedRoute.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "Route.h"
#import "YapDatabaseConnection.h"

@interface AdvancedRoute : Route

@property (nonatomic, weak, readonly) RoutingHTTPServer *server;
@property (nonatomic, strong, readonly) YapDatabaseConnection *connection;

- (instancetype)initInServer:(RoutingHTTPServer *)server;

//This is the router for HTTP verbs.
- (void)incomingRequest:(RouteRequest *)request
               response:(RouteResponse *)response;

//All verbs received redirected to their method.
- (void)getRequest:(RouteRequest *)request
          response:(RouteResponse *)response;
- (void)postRequest:(RouteRequest *)request
           response:(RouteResponse *)response;
- (void)putRequest:(RouteRequest *)request
          response:(RouteResponse *)response;
- (void)deleteRequest:(RouteRequest *)request
             response:(RouteResponse *)response;

@end