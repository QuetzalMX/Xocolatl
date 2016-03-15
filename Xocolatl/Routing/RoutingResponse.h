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

@property (nonatomic, strong, readonly, nullable) id jsonBody;

+ (instancetype)responseWithStatus:(NSInteger)status
                           andData:(NSData *)data;

//Convenience.
+ (instancetype)responseWithStatus:(NSInteger)status
                           andBody:(id)jsonBody;
+ (instancetype)responseWithError:(NSError *)error;

- (void)setCookieNamed:(NSString *)name
             withValue:(NSString *)value
              isSecure:(BOOL)isSecure
              httpOnly:(BOOL)httpOnly;

@end
