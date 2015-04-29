//
//  AppDelegate.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/11/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AppDelegate.h"

//Core
#import "XOCUser.h"
#import "RoutingHTTPServer.h"
#import "YapDatabase.h"
#import "AuthRequestManager.h"
#import "Route.h"
#import "LoginRoute.h"

//Example
#import "CruyffUser.h"
#import "HomeRoute.h"

@interface AppDelegate ()

@property (nonatomic, strong) RoutingHTTPServer *server;

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //Create the server.
    self.server = [[RoutingHTTPServer alloc] initAtPort:3000
                                           documentRoot:[@"~/Sites/Cruyff" stringByExpandingTildeInPath]
                                           databaseName:@"Cruyff"];
    
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

@end