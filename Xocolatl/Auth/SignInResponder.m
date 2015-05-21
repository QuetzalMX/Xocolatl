//
//  LoginRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SignInResponder.h"

#import "XocolatlUser.h"
#import "RoutingResponse.h"
#import "YapDatabase.h"

NSInteger const SecondsUntilAuthorizationExpires = 86400;

@implementation SignInResponder

- (NSDictionary *)methods;
{
    return @{HTTPVerbPOST: @"/api/signin"};
}

- (NSObject <HTTPResponse> *)responseForPOSTRequest:(HTTPMessage *)message
                                     withParameters:(NSDictionary *)parameters;
{
    //Attempt to log in the user with the given credentials.
    NSTimeInterval timeOfDeath = [[NSDate date] timeIntervalSince1970] + SecondsUntilAuthorizationExpires;
    NSString *username = message.parsedBody[@"username"];
    NSString *password = message.parsedBody[@"password"];
    
    __block XocolatlUser *registeredUser;
    __block NSString *authorization;
    __block NSError *error;
    __block NSDictionary *registeredUserJSON;
    [self.writeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        //Let's see if this user exists.
        XocolatlUser *fetchedUser = [XocolatlUser objectWithIdentifier:username
                                            usingTransaction:transaction];
        
        if (!fetchedUser) {
            //User is not registered.
            error = [NSError errorWithDomain:@"User Does Not Exist"
                                        code:404
                                    userInfo:@{@"reason": @"The requested user is not registered."}];
            return;
        }
        
        //The user exists. Is the password valid?
        if (![XocolatlUser verifyPasswordHashForUser:fetchedUser
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
        NSAssert(authorization, @"Auth should never be null");
        
        //Save the user.
        [fetchedUser saveUsingTransaction:transaction];
        registeredUserJSON = [registeredUser jsonRepresentationUsingTransaction:transaction];
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
    NSMutableDictionary *dictionaryWithAuth = [registeredUserJSON mutableCopy];
    dictionaryWithAuth[@"auth"] = authorization;
    dictionaryWithAuth[@"username"] = registeredUser.username;
    RoutingResponse *response = [RoutingResponse responseWithStatus:200
                                                            andBody:dictionaryWithAuth];
    
    [response setCookieNamed:@"username"
                   withValue:registeredUser.username
                    isSecure:YES
                    httpOnly:NO];
    
    [response setCookieNamed:@"auth"
                   withValue:authorization
                    isSecure:YES
                    httpOnly:NO];
    
    return response;
}

@end
