//
//  LoginRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SigninRoute.h"

#import "AuthRequestManager.h"
#import "XOCUser+Auth.h"
#import "YapDatabaseTransaction.h"

NSInteger const SecondsUntilAuthorizationExpires = 3600;

@implementation SigninRoute

- (NSDictionary *)methods;
{
    return @{@"GET": @"/",
             @"POST": @"/api/login"};
}

- (void)getRequest:(RouteRequest *)request response:(RouteResponse *)response;
{
    [response respondWithDynamicFile:[self.server.documentRoot stringByAppendingPathComponent:@"index.html"]
            andReplacementDictionary:@{@"title": @"Cruyff Football"}];
}

- (void)postRequest:(RouteRequest *)request response:(RouteResponse *)response;
{
    //Attempt to log in the user with the given credentials.
    NSTimeInterval timeOfDeath = [[NSDate date] timeIntervalSince1970] + SecondsUntilAuthorizationExpires;
    NSString *user = request.parsedBody[@"username"];
    NSString *password = request.parsedBody[@"password"];
    
    __block XOCUser *registeredUser;
    __block NSString *authorization;
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        //Let's see if this user exists.
        XOCUser *fetchedUser = [transaction objectForKey:user
                                            inCollection:UsersCollection];
        
        if (!fetchedUser) {
            //User is not registered.
            NSError *error = [NSError errorWithDomain:@"User Does Not Exist"
                                                 code:404
                                             userInfo:@{NSLocalizedDescriptionKey: @"The requested user is not registered."}];
            [response respondWithError:error];
            return;
        }
        
        //The user exists. Is the password valid?
        if (![XOCUser verifyPasswordHashForUser:fetchedUser
                                   withPassword:password]) {
            //Nope. Invalid password.
            NSError *error = [NSError errorWithDomain:@"Invalid Credentials"
                                                 code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"That password is not valid for the given username."}];
            
            [response respondWithError:error];
            return;
        }
        
        //The password is valid. Create an auth string and return the user.
        registeredUser = fetchedUser;
        authorization = [fetchedUser newAuthHeaderWithTimeOfDeath:timeOfDeath];
        
        //Save the user.
        [transaction setObject:fetchedUser
                        forKey:user
                  inCollection:UsersCollection];
    }];
    
    //Now that we have all the info, add our cookies and redirect the user back to home.
    [response setCookieNamed:@"timeOfDeath"
                   withValue:[NSString stringWithFormat:@"%.0f", timeOfDeath]
                    isSecure:YES
                    httpOnly:YES];
    
    [response setCookieNamed:@"username"
                   withValue:registeredUser.username
                    isSecure:YES
                    httpOnly:YES];
    
    [response setCookieNamed:@"auth"
                   withValue:authorization
                    isSecure:YES
                    httpOnly:YES];
    
    [response respondWithRedirect:@"/home"];
}

@end
