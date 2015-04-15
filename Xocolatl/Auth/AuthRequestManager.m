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
    
    [[NSNotificationCenter defaultCenter] addObserver:manager
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:database];
    
    return manager;
}

- (void)registerUser:(NSString *)user
        withPassword:(NSString *)password
  andCompletionBlock:(void (^)(XOCUser *, NSError *))completionBlock;
{
    XOCUser *newUser = [XOCUser newUserWithUsername:user
                                        andPassword:password];
    
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        XOCUser *registeredUser = [transaction objectForKey:newUser.username
                                               inCollection:UsersCollection];
        if (registeredUser) {
            completionBlock(nil, [NSError errorWithDomain:@"Account Creation"
                                                     code:403
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Username already exists."}]);
            return;
        }
        
        [transaction setObject:newUser
                        forKey:newUser.username
                  inCollection:UsersCollection];
        
        transaction.yapDatabaseModifiedNotificationCustomObject = @{@"RegisteredUser": newUser,
                                                                    @"completionBlock": completionBlock};
    }];
}

- (void)yapDatabaseModified:(NSNotification *)notification;
{
    NSDictionary *customObject = [notification.userInfo objectForKey:YapDatabaseCustomKey];
    void (^completionBlock)(XOCUser *, NSError *) = customObject[@"completionBlock"];
    XOCUser *user = customObject[@"RegisteredUser"];
    completionBlock(user, nil);
}

@end
