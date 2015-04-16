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
#import "XOCUser.h"

NSString *const UsersCollection = @"Users";

@interface AuthRequestManager ()

@property (nonatomic, strong) RoutingHTTPServer *server;
@property (nonatomic, strong) YapDatabaseConnection *connection;

@end

@implementation AuthRequestManager

+ (instancetype)requestManagerForServer:(RoutingHTTPServer *)server
                            andDatabase:(YapDatabase *)database;
{
    AuthRequestManager *manager = [[AuthRequestManager alloc] init];
    manager.server = server;
    manager.connection = [database newConnection];
    
    return manager;
}

- (void)registerUser:(NSString *)username
        withPassword:(NSString *)password
  andCompletionBlock:(void (^)(XOCUser *, NSError *))completionBlock;
{
    __block XOCUser *newUser;
    __block NSError *error;
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        XOCUser *registeredUser = [transaction objectForKey:username
                                               inCollection:UsersCollection];
        if (registeredUser) {
            error = [NSError errorWithDomain:@"Account Creation"
                                        code:403
                                    userInfo:@{NSLocalizedDescriptionKey: @"Username already exists."}];
        } else {
            newUser = [XOCUser newUserWithUsername:username];
            [newUser setHashedPassword:password];
            [transaction setObject:newUser
                            forKey:newUser.username
                      inCollection:UsersCollection];
        }
    }];
    
    completionBlock(newUser, error);
}

@end
