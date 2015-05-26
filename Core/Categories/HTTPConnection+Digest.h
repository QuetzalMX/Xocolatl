//
//  HTTPConnection+Digest.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <XocolatlFramework/XocolatlFramework.h>

@interface HTTPConnection (Digest)

/**
 *  Nonces must increment for each request from the client.
 */
@property (nonatomic) NSInteger lastNC;

/**
 *  A nonce is a server-specified string uniquely generated for each 401 response.
 */
@property (nonatomic, strong) NSString *nonce;

+ (NSString *)generateNonce;
+ (BOOL)hasRecentNonce:(NSString *)recentNonce;

@end
