//
//  NSString+randomString.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "NSString+randomString.h"

@implementation NSString (randomString)

+ (instancetype)randomString;
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *newNonce = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return newNonce;
}

@end
