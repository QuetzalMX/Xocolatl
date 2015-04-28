//
//  DynamicFileRoute.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "Route.h"

@class RoutingHTTPServer;

@interface DynamicFileRoute : Route

@property (nonatomic, weak, readonly) RoutingHTTPServer *server;

@property (nonatomic, copy, readonly) NSString *dynamicFilePath;
@property (nonatomic, copy, readonly) NSDictionary *replacementDictionary;

- (instancetype)initInServer:(RoutingHTTPServer *)server;

@end
