//
//  LoginRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SignInResponder.h"

#import "XOCUser+Auth.h"
#import "RoutingResponse.h"
#import "YapDatabase.h"

NSInteger const SecondsUntilAuthorizationExpires = 3600;

@implementation SignInResponder

- (NSDictionary *)methods;
{
    return @{@"POST": @"/api/login"};
}

- (NSObject <HTTPResponse> *)responseForPOSTRequest:(HTTPMessage *)message
                                     withParameters:(NSDictionary *)parameters;
{
    //Attempt to log in the user with the given credentials.
    NSTimeInterval timeOfDeath = [[NSDate date] timeIntervalSince1970] + SecondsUntilAuthorizationExpires;
    NSString *user = message.parsedBody[@"username"];
    NSString *password = message.parsedBody[@"password"];
    
    __block XOCUser *registeredUser;
    __block NSString *authorization;
    __block NSError *error;
    [self.writeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        //Let's see if this user exists.
        XOCUser *fetchedUser = [transaction objectForKey:user
                                            inCollection:UsersCollection];
        
        if (!fetchedUser) {
            //User is not registered.
            error = [NSError errorWithDomain:@"User Does Not Exist"
                                        code:404
                                    userInfo:@{@"reason": @"The requested user is not registered."}];
            return;
        }
        
        //The user exists. Is the password valid?
        if (![XOCUser verifyPasswordHashForUser:fetchedUser
                                   withPassword:password]) {
            //Nope. Invalid password.
            error = [NSError errorWithDomain:@"Invalid Credentials"
                                        code:400
                                    userInfo:@{@"reason": @"That password is not valid for the given username."}];
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
    
    if (!registeredUser) {
        return [RoutingResponse responseWithError:[NSError errorWithDomain:@"User Does Not Exist"
                                                                      code:404
                                                                  userInfo:@{@"reason": @"The requested user is not registered."}]];
    }
    
    if (error) {
        return [RoutingResponse responseWithError:error];
    }
    
    //Now that we have all the info, add our cookies and redirect the user back to home.
    RoutingResponse *response = [RoutingResponse responseWithStatus:200
                                                            andBody:registeredUser.jsonRepresentation];
    
    
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
    
    return response;
}

@end
