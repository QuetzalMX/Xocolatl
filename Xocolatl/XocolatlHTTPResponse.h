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
    XocolatlHTTPStatusCode204NoContent = 204,
    XocolatlHTTPStatusCode400BadRequest = 400,
    XocolatlHTTPStatusCode401Unauthorized = 401,
    XocolatlHTTPStatusCode403Forbidden = 403,
    XocolatlHTTPStatusCode404NotFound = 404,
    XocolatlHTTPStatusCode500ServerError = 500,
};

@interface XocolatlHTTPResponse : RoutingResponse

+ (instancetype)responseWithStatus:(XocolatlHTTPStatusCode)status
                           andBody:(id)jsonBody;

+ (instancetype)responseWithStatus:(XocolatlHTTPStatusCode)status
                           andData:(NSData *)data;

+ (instancetype)responseWithErrorCode:(XocolatlHTTPStatusCode)errorCode
                               reason:(NSString *)reason;

@end