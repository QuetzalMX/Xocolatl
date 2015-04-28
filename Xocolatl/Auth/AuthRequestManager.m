//
//  AuthRequestManager.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AuthRequestManager.h"

#import "RoutingHTTPServer.h"
#import "YapDatabase.h"
#import "XOCUser+Auth.h"
#import "NSData+hashedPassword.h"

NSString *const UsersCollection = @"Users";

@interface AuthRequestManager ()

@property (nonatomic, strong) RoutingHTTPServer *server;
@property (nonatomic, strong) YapDatabaseConnection *connection;

@end

@implementation AuthRequestManager

+ (instancetype)requestManagerForServer:(RoutingHTTPServer *)server;
{
    AuthRequestManager *manager = [[AuthRequestManager alloc] init];
    manager.server = server;
    manager.connection = [server.database newConnection];
    
    return manager;
}

- (void)loginUser:(NSString *)user
     withPassword:(NSString *)password
       timeOfDeath:(NSTimeInterval)timeInterval
andCompletionBlock:(void (^)(XOCUser *, NSString *, NSError *))completionBlock;
{
    __block XOCUser *registeredUser;
    __block NSError *error;
    __block NSString *authorization;
    [self.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        //Let's see if this user exists.
        XOCUser *fetchedUser = [transaction objectForKey:user
                                            inCollection:UsersCollection];
        
        if (!fetchedUser) {
            //User is not registered.
            error = [NSError errorWithDomain:@"User Does Not Exist"
                                        code:404
                                    userInfo:@{NSLocalizedDescriptionKey: @"The requested user is not registered."}];
            return;
        }
        
        //The user exists. Is the password valid?
        if (![XOCUser verifyPasswordHashForUser:fetchedUser
                                   withPassword:password]) {
            error = [NSError errorWithDomain:@"Invalid Credentials"
                                        code:400
                                    userInfo:@{NSLocalizedDescriptionKey: @"That password is not valid for the given username."}];
            return;
        }
        
        //The password is valid. Create an auth string and return the user.
        registeredUser = fetchedUser;
        authorization = [fetchedUser newAuthHeaderWithSessionDuration:timeInterval];
    }];
    
    completionBlock(registeredUser, authorization, error);
}

- (void)registerUserFromRequestBody:(NSDictionary *)requestbody
                           andClass:(Class)class
                 andCompletionBlock:(void (^)(XOCUser *, NSError *))completionBlock;
{
    //Attempt to register a new user.
    NSString *username = requestbody[@"username"];
    NSString *password = requestbody[@"password"];
    
    __block XOCUser *newUser;
    __block NSError *error;
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        //First, check if the user exists.
        XOCUser *registeredUser = [transaction objectForKey:username
                                               inCollection:UsersCollection];
        if (registeredUser) {
            //User exists. We're done.
            error = [NSError errorWithDomain:@"Account Creation"
                                        code:403
                                    userInfo:@{NSLocalizedDescriptionKey: @"Username already exists."}];
            return;
        }
        
        //User doesn't exist. Create it.
        newUser = [class newUserWithUsername:username];
        [newUser setHashedPassword:password];
        [newUser willRegisterUsingRequestBody:requestbody];
        [transaction setObject:newUser
                        forKey:newUser.username
                  inCollection:UsersCollection];
    }];
    
    completionBlock(newUser, error);
}

@end