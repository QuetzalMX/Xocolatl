//
//  DynamicFileRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "DynamicFileRoute.h"

#import "RoutingHTTPServer.h"

@interface DynamicFileRoute ()

@property (nonatomic, weak, readwrite) RoutingHTTPServer *server;
@property (nonatomic, copy, readwrite) NSString *dynamicFilePath;

@end

@implementation DynamicFileRoute

- (instancetype)initInServer:(RoutingHTTPServer *)server;
{
    if (self != [super init]) {
        return nil;
    }
    
    self.server = server;
    self.target = self;
    self.selector = @selector(incomingRequest:response:);
    [server addRoute:self];
    
    return self;
}

- (void)incomingRequest:(RouteRequest *)request
               response:(RouteResponse *)response;
{
    [response respondWithDynamicFile:self.dynamicFilePath
            andReplacementDictionary:self.replacementDictionary];
}

@end
