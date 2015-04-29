//
//  HomeRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HomeRoute.h"

@implementation HomeRoute

- (NSDictionary *)methods;
{
    return @{@"GET": @"/home"};
}

- (void)getRequest:(RouteRequest *)request response:(RouteResponse *)response;
{
    //Home
    NSString *path = [self.server.documentRoot stringByAppendingPathComponent:@"home.html"];
    NSString *navigationPath = [self.server.documentRoot stringByAppendingPathComponent:@"navigation.html"];
    NSString *navBar = [NSString stringWithContentsOfFile:navigationPath
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
    [response respondWithDynamicFile:path
            andReplacementDictionary:@{@"nav": navBar,
                                       @"username": self.user.username}];
}

- (void)errorAuthorizingRequest:(RouteRequest *)request
                       response:(RouteResponse *)response;
{
    [response respondWithRedirect:@"/"];
}

@end
