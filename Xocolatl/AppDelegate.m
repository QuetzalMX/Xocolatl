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
#import "IndexRoute.h"
#import "LoginRoute.h"

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
    IndexRoute *indexRoute = [[IndexRoute alloc] initInServer:self.server];
    [self.server addRoute:indexRoute];
    
    LoginRoute *loginRoute = [[LoginRoute alloc] initInServer:self.server];
    [self.server addRoute:loginRoute];
    
//    [self.server get:@"/signup" withBlock:^(RouteRequest *request, RouteResponse *response) {
//        NSString *path = [self.server.documentRoot stringByAppendingPathComponent:@"register.html"];
//        [response respondWithDynamicFile:path
//                andReplacementDictionary:@{@"title": @"Cruyff Football"}];
//    }];
//    
//    [self.server post:@"/api/signup" withBlock:^(RouteRequest *request, RouteResponse *response) {
//        [self.manager registerUserFromRequestBody:request.parsedBody
//                                         andClass:[CruyffUser class]
//                               andCompletionBlock:^(XOCUser *newUser, NSError *error) {
//                                   if (error) {
//                                       [response respondWithError:error];
//                                       return;
//                                   }
//                    
//                                   NSDictionary *userJSON = newUser.jsonRepresentation;
//                                   NSLog(@"%@", @{@"user": userJSON});
//                                   [response respondWithRedirect:@"/" andData:[NSJSONSerialization dataWithJSONObject:userJSON
//                                                                                                              options:0
//                                                                                                                error:nil]];
//                               }];
//    }];
//    
//    //Home
//    [self.server get:@"/home" withBlock:^(RouteRequest *request, RouteResponse *response) {
//        //Get the user from the cookie.
//        
//        NSString *path = [self.server.documentRoot stringByAppendingPathComponent:@"home.html"];
//        NSString *navigationPath = [self.server.documentRoot stringByAppendingPathComponent:@"navigation.html"];
//        NSString *navBar = [NSString stringWithContentsOfFile:navigationPath
//                                                     encoding:NSUTF8StringEncoding
//                                                        error:nil];
//        [response respondWithDynamicFile:path
//                andReplacementDictionary:@{@"nav": navBar}];
//    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
