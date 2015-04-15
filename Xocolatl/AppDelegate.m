//
//  AppDelegate.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/11/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AppDelegate.h"

#import "XOCUser.h"
#import "RoutingHTTPServer.h"
#import "YapDatabase.h"
#import "AuthRequestManager.h"

@interface AppDelegate ()

@property (nonatomic, strong) RoutingHTTPServer *server;
@property (nonatomic, strong) YapDatabase *database;
@property (nonatomic, strong) AuthRequestManager *manager;

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //Create the server.
    self.server = [[RoutingHTTPServer alloc] init];
    [self.server setPort:3000];
    [self.server setDocumentRoot:[@"~/Sites" stringByExpandingTildeInPath]];
    
    NSString *databasePath = [self.server.documentRoot stringByAppendingPathExtension:@"database.yap"];
    self.database = [[YapDatabase alloc] initWithPath:databasePath];
    
    self.manager = [AuthRequestManager requestManagerForServer:self.server
                                                   andDatabase:self.database];
    
    //Start the server.
    NSError *error;
    if (![self.server start:&error]) {
        NSLog(@"Error starting HTTP server: %@", error);
    }
    
    [self.server get:@"/" withBlock:^(RouteRequest *request, RouteResponse *response) {
        NSString *path = [self.server.documentRoot stringByAppendingPathComponent:@"index.html"];
        [response respondWithFile:path];
    }];
    
    [self.server post:@"/signup" withBlock:^(RouteRequest *request, RouteResponse *response) {
        
        [self.manager registerUser:request.parsedBody[@"username"]
                      withPassword:request.parsedBody[@"password"]
                andCompletionBlock:^(XOCUser *newUser, NSError *error) {
                    if (newUser) {
                        response.statusCode = 200;
                        [response respondWithString:[NSString stringWithFormat:@"%@", newUser.identifier]];
                    } else {
                        response.statusCode = error.code;
                        [response respondWithString:error.localizedDescription];
                    }
                }];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
