//
//  HTTPConnection+Digest.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPConnection+Digest.h"

#import <objc/runtime.h>

static const NSInteger HTTPConnectionNonceTimeout = 300;

@implementation HTTPConnection (Digest)

static dispatch_queue_t recentNonceQueue;
static NSMutableArray *recentNonces;

+ (void)initialize;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recentNonceQueue = dispatch_queue_create("HTTPConnection-Nonce", NULL);
        recentNonces = [[NSMutableArray alloc] initWithCapacity:5];
    });
}

/**
 * Generates and returns an authentication nonce.
 * A nonce is a server-specified string uniquely generated for each 401 response.
 * The default implementation uses a single nonce for each session.
 **/
+ (NSString *)generateNonce;
{
    // We use the Core Foundation UUID class to generate a nonce value for us
    // UUIDs (Universally Unique Identifiers) are 128-bit values guaranteed to be unique.
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *newNonce = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    
    // We have to remember that the HTTP protocol is stateless.
    // Even though with version 1.1 persistent connections are the norm, they are not guaranteed.
    // Thus if we generate a nonce for this connection,
    // it should be honored for other connections in the near future.
    //
    // In fact, this is absolutely necessary in order to support QuickTime.
    // When QuickTime makes it's initial connection, it will be unauthorized, and will receive a nonce.
    // It then disconnects, and creates a new connection with the nonce, and proper authentication.
    // If we don't honor the nonce for the second connection, QuickTime will repeat the process and never connect.
    dispatch_async(recentNonceQueue, ^
                   {
                       @autoreleasepool
                       {
                           [recentNonces addObject:newNonce];
                       }
                   });
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, HTTPConnectionNonceTimeout * NSEC_PER_SEC);
    dispatch_after(popTime, recentNonceQueue, ^
                   {
                       @autoreleasepool
                       {
                           [recentNonces removeObject:newNonce];
                       }
                   });
    
    return newNonce;
}

+ (BOOL)hasRecentNonce:(NSString *)recentNonce;
{
    __block BOOL result = NO;
    dispatch_sync(recentNonceQueue, ^
                  {
                      @autoreleasepool
                      {
                          result = [recentNonces containsObject:recentNonce];
                      }
                  });
    
    return result;
}

#pragma mark - Properties
- (void)setLastNC:(NSInteger)lastNC;
{
    objc_setAssociatedObject(self, @selector(lastNC), @(lastNC), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)lastNC;
{
    NSNumber *lastNCNumber = objc_getAssociatedObject(self, @selector(lastNC));
    return lastNCNumber.integerValue;
}

- (void)setNonce:(NSString *)nonce;
{
    objc_setAssociatedObject(self, @selector(nonce), nonce, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)nonce;
{
    return objc_getAssociatedObject(self, @selector(nonce));
}

@end