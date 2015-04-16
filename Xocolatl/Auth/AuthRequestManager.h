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

+ (instancetype)requestManagerForServer:(RoutingHTTPServer *)server
                            andDatabase:(YapDatabase *)database;

- (void)loginUser:(NSString *)user
     withPassword:(NSString *)password
andCompletionBlock:(void (^)(XOCUser *, NSError *))completionBlock;

- (void)registerUser:(NSString *)user
        withPassword:(NSString *)password
  andCompletionBlock:(void (^)(XOCUser *, NSError *))completionBlock;

@end
