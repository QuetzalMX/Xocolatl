//
//  RoutingResponse.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@interface RoutingResponse : NSObject <HTTPResponse>

+ (instancetype)responseWithStatus:(NSInteger)status andBody:(NSDictionary *)jsonBody;

//Convenience.
+ (instancetype)responseWithError:(NSError *)error;

- (void)setCookieNamed:(NSString *)name
             withValue:(NSString *)value
              isSecure:(BOOL)isSecure
              httpOnly:(BOOL)httpOnly;

@end
