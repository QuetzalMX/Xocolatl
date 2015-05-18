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
#import "SignInResponder.h"
#import "XocolatlUser.h"

@interface AppDelegate ()

@property (nonatomic, strong) XocolatlHTTPServer *server;
@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self.server = [XocolatlHTTPServer newServerNamed:@"Xocolatl"
                                     listeningAtPort:3000];
    
    [self.server setSignUpRoute:[SignUpResponder class]
                  withUserClass:[XocolatlUser class]];
    
    [self.server addDatabaseRoute:[SignInResponder class]];
    
/*
    //Import the certificate to push notifications
    NSString *path = [[NSBundle mainBundle] pathForResource:@"PushDevEnvironmentCertificate"
                                                     ofType:@"p12"];
    if (![[XocolatlAPNManager sharedManager] importP12Certificate:path
                                                      andPassword:@"password"]) {
        NSLog(@"Failed to initiate APN Manager");
    }
*/
    
    NSError *error;
    if (![self.server start:&error]) {
        NSLog(@"Server failed running: %@", error);
    }
}

@end