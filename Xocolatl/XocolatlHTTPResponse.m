//
//  XocolatlHTTPResponse.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlHTTPResponse.h"

@implementation XocolatlHTTPResponse

+ (instancetype)responseWithStatus:(XocolatlHTTPStatusCode)status
                           andBody:(id)jsonBody;
{
    return [super responseWithStatus:status
                             andBody:jsonBody];
}

+ (instancetype)responseWithStatus:(XocolatlHTTPStatusCode)status andData:(NSData *)data;
{
    return [super responseWithStatus:status
                             andData:data];
}

+ (instancetype)responseWithErrorCode:(XocolatlHTTPStatusCode)errorCode
                               reason:(NSString *)reason;
{
    NSString *errorDomain = [self errorDomainForCode:errorCode] ?: @"";
    if (!reason) {
        reason = errorDomain;
    }
    
    return [self responseWithError:[NSError errorWithDomain:errorDomain
                                                       code:errorCode
                                                   userInfo:@{@"reason": reason}]];
}

+ (NSString *)errorDomainForCode:(XocolatlHTTPStatusCode)code;
{
    switch (code) {
        case XocolatlHTTPStatusCode403Forbidden:
            return @"Forbidden";
            break;
            
        default:
            return nil;
            break;
    }
}

@end
