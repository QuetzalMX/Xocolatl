//
//  HTTPResponseHandler.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/1/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPResponse.h"
#import "HTTPMessage+Xocolatl.h"

@class RoutingResponse;

@interface RoutingResponder : NSObject

@property (nonatomic, copy, readonly) NSDictionary *methods;

- (NSRegularExpression *)regexForMethod:(NSString *)method;
- (NSArray *)keysForMethod:(NSString *)method;

//Routing
- (RoutingResponse *)responseForRequest:(HTTPMessage *)message
                         withParameters:(NSDictionary *)parameters;

- (RoutingResponse *)responseForGETRequest:(HTTPMessage *)message
                            withParameters:(NSDictionary *)parameters;
- (RoutingResponse *)responseForPOSTRequest:(HTTPMessage *)message
                             withParameters:(NSDictionary *)parameters;
- (RoutingResponse *)responseForPUTRequest:(HTTPMessage *)message
                            withParameters:(NSDictionary *)parameters;
- (RoutingResponse *)responseForDELETERequest:(HTTPMessage *)message
                               withParameters:(NSDictionary *)parameters;

@end