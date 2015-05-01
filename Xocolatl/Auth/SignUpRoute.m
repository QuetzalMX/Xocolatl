//
//  SignUpRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SignUpRoute.h"

#import "XOCUser+Auth.h"
#import "YapDatabase.h"

@implementation SignUpRoute

- (NSDictionary *)methods;
{
    return @{HTTPMethodGET: @"/signup",
             HTTPMethodPOST: @"/api/signup"};
}

- (void)getRequest:(RouteRequest *)request response:(RouteResponse *)response;
{
    NSString *path = [self.server.documentRoot stringByAppendingPathComponent:@"register.html"];
    [response respondWithDynamicFile:path
            andReplacementDictionary:@{@"title": @"SuperContabilidadMX"}];
}

- (void)postRequest:(RouteRequest *)request response:(RouteResponse *)response;
{
    //Attempt to register a new user.
    NSString *username = request.parsedBody[@"username"];
    NSString *password = request.parsedBody[@"password"];

    __block XOCUser *newUser;
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        //First, check if the user exists.
        XOCUser *registeredUser = [transaction objectForKey:username
                                               inCollection:UsersCollection];
        if (registeredUser) {
            //User exists. Deny the registration.
            NSError *error = [NSError errorWithDomain:@"Account Creation"
                                                 code:403
                                             userInfo:@{NSLocalizedDescriptionKey: @"Username already exists."}];
            [response respondWithError:error];
            return;
        }

        //User doesn't exist. Create it.
        newUser = [XOCUser newUserWithUsername:username];
        [newUser setHashedPassword:password];
        [newUser willRegisterUsingRequestBody:request.parsedBody];
        [transaction setObject:newUser
                        forKey:newUser.username
                  inCollection:UsersCollection];
    }];
    
    [response respondWithRedirect:@"/" andData:[NSJSONSerialization dataWithJSONObject:newUser.jsonRepresentation
                                                                               options:0
                                                                                 error:nil]];
}

@end
