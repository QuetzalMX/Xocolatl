//
//  SignUpRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "SignUpRoute.h"

@implementation SignUpRoute

- (NSDictionary *)methods;
{
    return @{@"GET": @"/signup"};
}

- (void)getRequest:(RouteRequest *)request response:(RouteResponse *)response;
{
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
}

@end
