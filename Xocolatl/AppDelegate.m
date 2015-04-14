//
//  AppDelegate.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/11/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AppDelegate.h"
#import "RoutingHTTPServer.h"

@interface AppDelegate ()

@property RoutingHTTPServer *server;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self.server = [[RoutingHTTPServer alloc] init];
    [self.server setPort:3000];
    [self.server setDocumentRoot:[@"~/Sites" stringByExpandingTildeInPath]];
    
    NSError *error;
    if (![self.server start:&error]) {
        NSLog(@"Error starting HTTP server: %@", error);
    }
    
    [self.server get:@"/hello" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [response respondWithString:@"World!"];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
