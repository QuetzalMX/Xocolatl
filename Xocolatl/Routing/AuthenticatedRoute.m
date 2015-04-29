//
//  AuthenticatedRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AuthenticatedRoute.h"

#import "XOCUser+Auth.h"
#import "YapDatabaseTransaction.h"

@implementation AuthenticatedRoute

- (void)incomingRequest:(RouteRequest *)request
               response:(RouteResponse *)response;
{
    //Parse the cookies to see if we have an authorized user.
    NSString *cookie = request.headers[@"cookie"];
    NSString *cookieWithoutSemiColons = [cookie stringByReplacingOccurrencesOfString:@";"
                                                                          withString:@""];
    NSArray *subCookies = [cookieWithoutSemiColons componentsSeparatedByString:@" "];
    
    NSMutableDictionary *parsedCookies = [NSMutableDictionary new];
    for (NSString *subCookie in subCookies) {
        NSArray *cookieFieldAndValue = [subCookie componentsSeparatedByString:@"="];
        if (cookieFieldAndValue.count < 2) {
            continue;
        }
        
        parsedCookies[cookieFieldAndValue.firstObject] = cookieFieldAndValue.lastObject;
    }
    
    NSString *username = parsedCookies[@"username"];
    NSString *auth = parsedCookies[@"auth"];
    NSString *expiration = parsedCookies[@"timeOfDeath"];
    if (!username || username.length <= 0 ||
        !auth || auth.length <= 0 ||
        !expiration || expiration.length <= 0) {
        //No user or authorization.
        [self errorAuthorizingRequest:request
                             response:response];
        return;
    }
    
    //There appears to be user, expiration and authorization.
    __block XOCUser *user;
    __block BOOL isValidAuth;
    [self.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        user = [transaction objectForKey:username
                            inCollection:UsersCollection];
        
        isValidAuth = [user validateAuthHeader:auth
                               withTimeOfDeath:expiration.integerValue];
    }];
    
    if (isValidAuth) {
        [self incomingAuthorizedRequest:request
                                forUser:user
                               response:response];
    } else {
        [self errorAuthorizingRequest:request
                             response:response];
    }
}

- (void)incomingAuthorizedRequest:(RouteRequest *)request
                          forUser:(XOCUser *)user
                         response:(RouteResponse *)response;
{
    //Used by subclasses.
    NSAssert(1==2, @"You forgot to subclass incomingAuthorizedRequest:response");
}

- (void)errorAuthorizingRequest:(RouteRequest *)request
                       response:(RouteResponse *)response;
{
    //Used by subclasses.
    NSAssert(1==2, @"You forgot to subclass errorAuthorizingRequest:response:");
}

@end
