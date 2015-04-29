//
//  DynamicFileRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "DynamicFileRoute.h"
#import "RoutingHTTPServer.h"

@implementation DynamicFileRoute

- (void)incomingRequest:(RouteRequest *)request
               response:(RouteResponse *)response;
{
    [response respondWithDynamicFile:self.dynamicFilePath
            andReplacementDictionary:self.replacementDictionary];
}

@end
