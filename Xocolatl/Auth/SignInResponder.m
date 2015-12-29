//
//  LoginRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SignInResponder.h"

#import "XocolatlUser.h"
#import "XocolatlHTTPResponse.h"
#import "YapDatabase.h"
#import "HTTPVerbs.h"

#import "NSError+XocolatlHTTPError.h"
#import "XocolatlModelObject+YapDatabase.h"

#import <objc/runtime.h>

@implementation RoutingResponse (SignInResponder)

- (void)setSignedInUser:(XocolatlUser *)registeredUser;
{
    objc_setAssociatedObject(self, @selector(signedInUser), registeredUser, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (XocolatlUser *)signedInUser;
{
    return objc_getAssociatedObject(self, @selector(signedInUser));
}

@end

@implementation SignInResponder

- (NSDictionary *)methods;
{
    return @{HTTPVerbPOST: @"/api/signin"};
}

- (NSObject <HTTPResponse> *)responseForPOSTRequest:(HTTPMessage *)message
                                     withParameters:(NSDictionary *)parameters;
{
    // Attempt to log in the user with the given credentials.
    NSString *username = message.parsedBody[@"username"];
    NSString *password = message.parsedBody[@"password"];
    
    if (!username || username.length <= 0 || !password || password.length <= 0)
    {
        return [XocolatlHTTPResponse responseWithErrorCode:XocolatlHTTPStatusCode400BadRequest
                                                    reason:@"Missing username or password"];
    }
    
    __block XocolatlUser *registeredUser;
    __block NSString *authorization;
    __block NSError *error;
    __block NSDictionary *registeredUserJSON;
    [self.writeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        // Let's see if this user exists.
        XocolatlUser *fetchedUser = [XocolatlUser find:username
                                      usingTransaction:transaction];
        
        if (!fetchedUser)
        {
            // User is not registered.
            error = [NSError errorWithHTTPCode:XocolatlHTTPStatusCode404NotFound
                                     andReason:@"The requested user is not registered."];
            return;
        }
        
        // The user exists. Is the password valid?
        if (![XocolatlUser verifyPasswordHashForUser:fetchedUser
                                        withPassword:password])
        {
            //Nope. Invalid password.
            error = [NSError errorWithHTTPCode:XocolatlHTTPStatusCode400BadRequest
                                     andReason:@"That password is not valid for the given username."];
            return;
        }
        
        // The password is valid. Create an auth string and return the user.
        registeredUser = fetchedUser;
        authorization = [fetchedUser newAuthHeaderWithDefaultExpiration];
        NSAssert(authorization, @"Auth should never be null");
        
        // Save the user.
        [fetchedUser saveUsingTransaction:transaction];
        registeredUserJSON = [registeredUser jsonRepresentationUsingTransaction:transaction];
    }];
    
    if (!registeredUser)
    {
        return [XocolatlHTTPResponse responseWithErrorCode:XocolatlHTTPStatusCode404NotFound
                                                    reason:@"The requested user is not registered."];
    }
    
    if (error)
    {
        return [XocolatlHTTPResponse responseWithError:error];
    }
    
    // Now that we have all the info, add our cookies and redirect the user back to home.
    NSMutableDictionary *dictionaryWithAuth = [registeredUserJSON mutableCopy];
    dictionaryWithAuth[@"auth"] = authorization;
    dictionaryWithAuth[@"username"] = registeredUser.identifier;
    XocolatlHTTPResponse *response = [XocolatlHTTPResponse responseWithStatus:XocolatlHTTPStatusCode200OK
                                                                      andBody:dictionaryWithAuth];
    
    response.signedInUser = registeredUser;
    
    [response setCookieNamed:@"username"
                   withValue:registeredUser.identifier
                    isSecure:YES
                    httpOnly:NO];
    
    [response setCookieNamed:@"auth"
                   withValue:authorization
                    isSecure:YES
                    httpOnly:NO];
    
    return response;
}

@end
