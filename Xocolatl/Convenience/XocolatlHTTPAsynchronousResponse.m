//
//  XocolatlHTTPAsynchronousResponse.m
//  Xocolatl
//
//  Created by Fernando Olivares on 9/18/15.
//  Copyright © 2015 Quetzal. All rights reserved.
//

#import "XocolatlHTTPAsynchronousResponse.h"

@interface XocolatlHTTPAsynchronousResponse ()

@property (nonatomic) XocolatlHTTPAsynchronousResponseType asyncType;
@property (nonatomic, getter=shouldDelayResponseHeaders) BOOL delayResponseHeaders;

/**
 *  We are very specifically overwriting this property so we can modify it.
 *  Its declaration in HTTPResponse.h sets it as readonly.
 */
@property (nonatomic, getter=isDone, readwrite) BOOL done;

@end

@implementation XocolatlHTTPAsynchronousResponse

+ (instancetype)responseWithAsynchronousType:(XocolatlHTTPAsynchronousResponseType)asyncType
                          shouldDelayHeaders:(BOOL)delayHeaders;

{
    XocolatlHTTPAsynchronousResponse *response = [[XocolatlHTTPAsynchronousResponse alloc] init];
    response.asyncType = asyncType;
    response.delayResponseHeaders = delayHeaders;
    return response;
}

- (BOOL)isAsynchronous;
{
    return YES;
}

- (BOOL)isDone;
{
    return self.isDone;
}

- (BOOL)isChunked;
{
    return (self.asyncType == XocolatlHTTPAsynchronousResponseTypeChunked);
}

- (BOOL)delayResponseHeaders;
{
    return self.shouldDelayResponseHeaders;
}

- (NSData *)readDataOfLength:(NSUInteger)length;
{
    return nil;
}

@end