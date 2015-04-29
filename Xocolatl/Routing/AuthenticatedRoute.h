//
//  AuthenticatedRoute.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AdvancedRoute.h"
#import "XOCUser.h"

@interface AuthenticatedRoute : AdvancedRoute

@property (nonatomic, strong, readonly) XOCUser *user;

- (void)errorAuthorizingRequest:(RouteRequest *)request
                       response:(RouteResponse *)response;

@end