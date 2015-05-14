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
#import "XocolatlHTTPServer.h"
#import "SignUpResponder.h"
#import "XOCUser.h"

@interface AppDelegate ()

@property (nonatomic, strong) XocolatlHTTPServer *server;
@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self.server = [XocolatlHTTPServer newServerNamed:@"Xocolatl"
                                     listeningAtPort:3000];
    
    [self.server setSignUpRoute:[SignUpResponder class]
                  withUserClass:[XOCUser class]];
    
    NSError *error;
    if (![self.server start:&error]) {
        NSLog(@"Server failed running: %@", error);
    }
}

@end