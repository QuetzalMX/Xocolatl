//
//  AuthRequestManager.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RoutingHTTPServer;
@class XOCUser;
@class YapDatabase;

@interface AuthRequestManager : NSObject

+ (instancetype)requestManagerForServer:(RoutingHTTPServer *)server;

- (void)loginUser:(NSString *)user
     withPassword:(NSString *)password
       timeOfDeath:(NSTimeInterval)timeInterval
andCompletionBlock:(void (^)(XOCUser *, NSString *, NSError *))completionBlock;

#warning This is ugly. We're passing class so that the user can subclass XOCUser and we can create it, but I'm not 100% sure about this.
- (void)registerUserFromRequestBody:(NSDictionary *)requestbody
                           andClass:(Class)class
andCompletionBlock:(void (^)(XOCUser *, NSError *))completionBlock;

@end