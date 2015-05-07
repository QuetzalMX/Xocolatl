//
//  AppDelegate.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/11/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.

#import "AppDelegate.h"

//Core
#import "RoutingHTTPServer.h"

//Auth
#import "SignUpResponder.h"
#import "SignInResponder.h"
#import "XOCUser.h"
#import "YapDatabase.h"
#import "XOCUsersResponder.h"

@interface AppDelegate ()

@property (nonatomic, strong) RoutingHTTPServer *server;
@property (nonatomic, strong) YapDatabase *database;
@property (nonatomic, strong) YapDatabaseConnection *writeConnection;
@property (nonatomic, strong) YapDatabaseConnection *readConnection;
@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //Create the server.
    NSString *documentRoot = [@"~/Sites/SuperContabilidadMX" stringByExpandingTildeInPath];
    self.server = [[RoutingHTTPServer alloc] initAtPort:3000];
    [self.server setDocumentRoot:documentRoot];
    
    //Let's see if we can create the database.
    NSString *databaseFolderPath = [documentRoot stringByAppendingString:@"/database"];
    BOOL isDirectory = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:databaseFolderPath
                                              isDirectory:&isDirectory]) {
        //The database folder doesn't exist. Create it.
        NSError *databaseFolderCreationError;
        [[NSFileManager defaultManager] createDirectoryAtPath:databaseFolderPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&databaseFolderCreationError];
        if (databaseFolderCreationError) {
            //The database folder couldn't be created. Something is wrong.
            return;
        }
    };
    
    //We're good to go. Create our databases.
    NSString *databaseWithFileExtension = [NSString stringWithFormat:@"%@/SuperContabilidadMX.yap", databaseFolderPath];
    self.database = [[YapDatabase alloc] initWithPath:databaseWithFileExtension];
    self.readConnection = [self.database newConnection];
    self.readConnection.permittedTransactions = YDB_AnyReadTransaction;
    
    self.writeConnection = [self.database newConnection];
    self.writeConnection.permittedTransactions = YDB_AnyReadWriteTransaction;
    
    //Start the server.
    NSError *error;
    if (![self.server start:&error]) {
        NSLog(@"Error starting HTTP server: %@", error);
        return;
    }
    
    //Configure the routes.
    SignInResponder *loginRoute = [[SignInResponder alloc] initWithReadConnection:self.readConnection
                                                               andWriteConnection:self.writeConnection
                                                                         inServer:self.server];
    [self.server addResponseHandler:loginRoute];
    
    SignUpResponder *signUpRoute = [[SignUpResponder alloc] initWithReadConnection:self.readConnection
                                                                andWriteConnection:self.writeConnection
                                                                          inServer:self.server
                                                                     withUserClass:[XOCUser class]];
    [self.server addResponseHandler:signUpRoute];
    
    XOCUsersResponder *responder = [[XOCUsersResponder alloc] initWithReadConnection:self.readConnection
                                                                  andWriteConnection:self.writeConnection
                                                                            inServer:self.server];
    [self.server addResponseHandler:responder];
}

@end