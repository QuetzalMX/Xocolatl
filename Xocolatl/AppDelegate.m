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
#import "Route.h"

//Cruyff
#import "CruyffUser.h"
#import "LoginRoute.h"
#import "HomeRoute.h"

@interface AppDelegate ()

@property (nonatomic, strong) RoutingHTTPServer *server;
@property (nonatomic, strong) AuthRequestManager *manager;

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //Create the server.
    self.server = [[RoutingHTTPServer alloc] initWithPort:3000
                                             documentRoot:[@"~/Sites/Cruyff" stringByExpandingTildeInPath]
                                             databaseName:@"Cruyff"];
    
    //Create our auth manager.
    self.manager = [AuthRequestManager requestManagerForServer:self.server];
    
    //Start the server.
    NSError *error;
    if (![self.server start:&error]) {
        NSLog(@"Error starting HTTP server: %@", error);
        return;
    }
    
    //Configure the routes.
    LoginRoute *loginRoute = [[LoginRoute alloc] initInServer:self.server];
    [self.server addRoute:loginRoute];
    
    HomeRoute *homeRoute = [[HomeRoute alloc] initInServer:self.server];
    [self.server addRoute:homeRoute];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
