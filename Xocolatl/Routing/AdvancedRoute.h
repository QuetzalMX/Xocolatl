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
- (void)incomingRequest:(RouteRequest *)request
               response:(RouteResponse *)response;

@end
