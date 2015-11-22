//
//  NSError+XocolatlHTTPError.m
//  Xocolatl
//
//  Created by Fernando Olivares on 11/18/15.
//  Copyright © 2015 Quetzal. All rights reserved.
//

#import "NSError+XocolatlHTTPError.h"

NSString * const XocolatlHTTPErrorDomain = @"XocolatlHTTPErrorDomain";

@implementation NSError (XocolatlHTTPError)

+ (NSError *)errorWithHTTPCode:(XocolatlHTTPStatusCode)code andReason:(NSString *)reason;
{
    return [NSError errorWithDomain:XocolatlHTTPErrorDomain
                               code:code
                           userInfo:@{@"reason": reason}];
}

@end