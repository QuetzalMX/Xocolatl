//
//  NSData+hashedPassword.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "NSData+hashedPassword.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (hashedPassword)

+ (NSData *)SHA256passwordUsing:(NSString *)password
                  andSaltPrefix:(NSString *)salt;
{
    NSString *saltedPasswordString = [NSString stringWithFormat:@"%@%@", salt, password];
    NSData *saltedPasswordData = [saltedPasswordString dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *hashedPasswordData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(saltedPasswordData.bytes,
              (CC_LONG)saltedPasswordData.length,
              hashedPasswordData.mutableBytes);
    
    return hashedPasswordData;
}

- (NSString *)SHA256String;
{
    NSMutableString *string = [NSMutableString stringWithCapacity:self.length * 2];
    const unsigned char *dataBytes = self.bytes;
    for (NSInteger idx = 0; idx < self.length; ++idx) {
        [string appendFormat:@"%02x", dataBytes[idx]];
    }
    
    return string;
}

@end
