//
//  AppDelegate.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/11/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.

#import "AppDelegate.h"

//Core
#import "RoutingHTTPServer.h"
#import "Route.h"
#import "SigninRoute.h"
#import "XOCUser.h"
#import "YapDatabase.h"

@interface AppDelegate ()

@property (nonatomic, strong) RoutingHTTPServer *server;
@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //Create the server.
    self.server = [[RoutingHTTPServer alloc] initAtPort:3000
                                           documentRoot:[@"~/Sites/SuperContabilidadMX" stringByExpandingTildeInPath]
                                           databaseName:@"SuperContabilidadMX"];
    
    //Start the server.
    NSError *error;
    if (![self.server start:&error]) {
        NSLog(@"Error starting HTTP server: %@", error);
        return;
    }
    
    //Configure the routes.
    SigninRoute *loginRoute = [[SigninRoute alloc] initInServer:self.server];
    [self.server addRoute:loginRoute];
}

@end