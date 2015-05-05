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

#import <objc/runtime.h>

@implementation RoutingResponse (SignUpResponder)

- (void)setRegisteredUser:(XOCUser *)registeredUser;
{
    objc_setAssociatedObject(self, @selector(registeredUser), registeredUser, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (XOCUser *)registeredUser;
{
    return objc_getAssociatedObject(self, @selector(registeredUser));
}

@end

@implementation SignUpResponder

- (instancetype)initWithReadConnection:(YapDatabaseConnection *)readConnection
                    andWriteConnection:(YapDatabaseConnection *)writeConnection
                              inServer:(RoutingHTTPServer *)server
                         withUserClass:(Class)userClass;
{
    if (self != [super initWithReadConnection:readConnection
                           andWriteConnection:writeConnection
                                     inServer:server]) {
        return nil;
    }
    
    self.userClass = userClass;
    
    return self;
}

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
        newUser = [self.userClass newUserWithUsername:username
                                          andPassword:password];
        [newUser willRegisterUsingRequestBody:request.parsedBody];
        [transaction setObject:newUser
                        forKey:newUser.username
                  inCollection:UsersCollection];
    }];
    
    if (error) {
        return [RoutingResponse responseWithError:error];
    }
    
    RoutingResponse *successResponse = [RoutingResponse responseWithStatus:200
                                                                   andBody:newUser.jsonRepresentation];
    successResponse.registeredUser = newUser;
    return successResponse;
}

@end
