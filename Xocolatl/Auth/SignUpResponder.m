//
//  SignUpRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SignUpResponder.h"

#import "YapDatabase.h"
#import "XocolatlHTTPResponse.h"
#import "XocolatlUser.h"

#import <objc/runtime.h>

@implementation RoutingResponse (SignUpResponder)

- (void)setRegisteredUser:(XocolatlUser *)registeredUser;
{
    objc_setAssociatedObject(self, @selector(registeredUser), registeredUser, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (XocolatlUser *)registeredUser;
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
    return @{HTTPVerbPOST: @"/api/signup"};
}

- (RoutingResponse *)responseForPOSTRequest:(HTTPMessage *)request
                             withParameters:(NSDictionary *)parameters;
{
    //Attempt to register a new user.
    NSString *username = request.parsedBody[@"username"];
    NSString *password = request.parsedBody[@"password"];
    
    if (![username isKindOfClass:[NSString class]]) {
        return [XocolatlHTTPResponse responseWithErrorCode:XocolatlHTTPStatusCode400BadRequest
                                                    reason:@"Username is invalid."];
    }
    
    if (![password isKindOfClass:[NSString class]]) {
        return [XocolatlHTTPResponse responseWithErrorCode:XocolatlHTTPStatusCode400BadRequest
                                                    reason:@"Password is invalid"];
    }

    __block XocolatlUser *newUser;
    __block BOOL alreadyRegistered = NO;
    __block NSDictionary *newUserJSON;
    [self.writeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        //First, check if the user exists.
        XocolatlUser *registeredUser = [XocolatlUser objectWithIdentifier:username
                                                         usingTransaction:transaction];
        if (registeredUser) {
            //User exists. Deny the registration.
            alreadyRegistered = YES;
            return;
        }

        //User doesn't exist. Create it.
        newUser = [self.userClass newUserWithUsername:username
                                          andPassword:password];
        
        [self willSaveUser:newUser
          usingRequestBody:request.parsedBody];
        
        [newUser saveUsingTransaction:transaction];
        
        newUserJSON = [newUser jsonRepresentationUsingTransaction:transaction];
    }];
    
    if (alreadyRegistered) {
        return [XocolatlHTTPResponse responseWithErrorCode:XocolatlHTTPStatusCode403Forbidden
                                                    reason:@"User is already registered."];
    }
    
    RoutingResponse *successResponse = [RoutingResponse responseWithStatus:XocolatlHTTPStatusCode201Created
                                                                   andBody:newUserJSON];
    successResponse.registeredUser = newUser;
    return successResponse;
}

- (void)willSaveUser:(XocolatlUser *)user
    usingRequestBody:(id)body;
{
    //Used by subclasses.
}

@end
