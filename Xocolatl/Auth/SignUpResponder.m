//
//  SignUpRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SignUpResponder.h"

#import "XOCUser+Auth.h"
#import "YapDatabase.h"
#import "RoutingResponse.h"

@implementation SignUpResponder

- (NSDictionary *)methods;
{
    return @{@"POST": @"/api/signup"};
}

- (RoutingResponse *)responseForPOSTRequest:(HTTPMessage *)request
                             withParameters:(NSDictionary *)parameters;
{
    //Attempt to register a new user.
    NSString *username = request.parsedBody[@"username"];
    NSString *password = request.parsedBody[@"password"];

    __block XOCUser *newUser;
    __block NSError *error;
    [self.writeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        //First, check if the user exists.
        XOCUser *registeredUser = [transaction objectForKey:username
                                               inCollection:UsersCollection];
        if (registeredUser) {
            //User exists. Deny the registration.
            error = [NSError errorWithDomain:@"Account Creation"
                                        code:403
                                    userInfo:@{NSLocalizedDescriptionKey: @"Username already exists."}];
            return;
        }

        //User doesn't exist. Create it.
        newUser = [XOCUser newUserWithUsername:username
                                   andPassword:password];
        [newUser willRegisterUsingRequestBody:request.parsedBody];
        [transaction setObject:newUser
                        forKey:newUser.username
                  inCollection:UsersCollection];
    }];
    
    if (error) {
        return [RoutingResponse responseWithError:error];
    }
    
    return [RoutingResponse responseWithStatus:200
                                       andBody:newUser.jsonRepresentation];
}

@end
