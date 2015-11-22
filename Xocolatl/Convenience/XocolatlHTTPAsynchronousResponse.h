//
//  XocolatlHTTPAsynchronousResponse.h
//  Xocolatl
//
//  Created by Fernando Olivares on 9/18/15.
//  Copyright © 2015 Quetzal. All rights reserved.
//

#import <XocolatlFramework/XocolatlFramework.h>

typedef NS_ENUM(NSUInteger, XocolatlHTTPAsynchronousResponseType) {
    XocolatlHTTPAsynchronousResponseTypeChunked,
    XocolatlHTTPAsynchronousResponseTypeRanged,
};

@interface XocolatlHTTPAsynchronousResponse : XocolatlHTTPResponse

+ (instancetype)responseWithAsynchronousType:(XocolatlHTTPAsynchronousResponseType)asyncType
                          shouldDelayHeaders:(BOOL)delayHeaders;

- (void)hasNewData:(NSData *)data;

@end
