//
//  LoginRoute.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "DatabaseResponder.h"

#import "RoutingResponse.h"

@interface SignInResponder : DatabaseResponder

@end

@interface RoutingResponse (SignInResponder)

@property (nonatomic, strong) XocolatlUser *signedInUser;

@end