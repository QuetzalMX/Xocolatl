//
//  XocolatlHTTPResponse.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "RoutingResponse.h"

typedef NS_ENUM(NSUInteger, XocolatlHTTPStatusCode) {
    XocolatlHTTPStatusCode200OK = 200,
    XocolatlHTTPStatusCode201Created = 201,
    XocolatlHTTPStatusCode400BadRequest = 400,
    XocolatlHTTPStatusCode403Forbidden = 403,
    XocolatlHTTPStatusCode404NotFound = 404,
};

@interface XocolatlHTTPResponse : RoutingResponse

+ (instancetype)responseWithErrorCode:(XocolatlHTTPStatusCode)errorCode
                               reason:(NSString *)reason;

@end
