//
//  XocolatlHTTPResponse.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlHTTPResponse.h"

@implementation XocolatlHTTPResponse

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
