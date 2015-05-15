//
//  RoutingResponse.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "RoutingResponse.h"

@interface RoutingResponse ()

@property (nonatomic, strong) NSMutableDictionary *mutableHeaders;
@property (nonatomic, strong) NSData *data;

@end

@implementation RoutingResponse

//HTTPMessage is a protocol, so must manually synthesize.
@synthesize contentLength = _contentLength;
@synthesize offset = _offset;
@synthesize done = _done;

@synthesize delayResponseHeaders = _delayResponseHeaders;
@synthesize status = _status;
@synthesize httpHeaders = _httpHeaders;
@synthesize isChunked = _isChunked;

+ (instancetype)responseWithStatus:(NSInteger)status
                           andData:(NSData *)data;
{
    RoutingResponse *response = [[self alloc] init];
    response.status = status;
    response.data = data;
    return response;
}

+ (instancetype)responseWithError:(NSError *)error;
{
    return [self responseWithStatus:error.code
                            andBody:error.userInfo];
}

+ (instancetype)responseWithStatus:(NSInteger)status
                           andBody:(NSDictionary *)jsonBody;
{
    NSData *bodyData;
    if (jsonBody) {
        NSError *parsingError;
        bodyData = [NSJSONSerialization dataWithJSONObject:jsonBody
                                                   options:0
                                                     error:&parsingError];
        
        if (parsingError) {
            return nil;
        }
    }
    
    return [self responseWithStatus:status
                            andData:bodyData];
}

- (instancetype)init;
{
    if (self != [super init]) {
        return nil;
    }
    
    _mutableHeaders = [NSMutableDictionary dictionary];
    _mutableHeaders[@"Content-Type"] = @"application/json";
    
    return self;
}

#pragma mark - Cookies
- (void)setCookieNamed:(NSString *)name
             withValue:(NSString *)value
              isSecure:(BOOL)isSecure
              httpOnly:(BOOL)httpOnly;
{
    //Is this the first cookie we save?
    NSMutableArray *cookies = self.mutableHeaders[@"Set-Cookie"];
    if (!cookies) {
        //It is. Create our cookie jar.
        cookies = [NSMutableArray array];
        self.mutableHeaders[@"Set-Cookie"] = cookies;
    }
    
    //Bake the cookie.
    NSMutableString *formedCookie = [NSMutableString stringWithFormat:@"%@=%@; domain=localhost; path=/;", name, value];
    if (isSecure) {
        [formedCookie appendFormat:@" secure;"];
    }
    
    if (httpOnly) {
        [formedCookie appendFormat:@" HTTPOnly;"];
    }
    
    //Save it.
    [cookies addObject:[formedCookie copy]];
}

#pragma mark - HTTPMessage (Required)
- (NSUInteger)contentLength;
{
    return self.data.length;
}

- (BOOL)isDone;
{
    return (self.offset == self.data.length);
}

- (NSData *)readDataOfLength:(NSUInteger)requestedLength;
{
    NSUInteger remaining = self.data.length - self.offset;
    NSUInteger length = requestedLength < remaining ? requestedLength : remaining;
    
    void *bytes = (void *)(self.data.bytes + self.offset);
    
    self.offset += requestedLength;
    
    return [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:NO];
}

- (NSDictionary *)httpHeaders;
{
    return [self.mutableHeaders copy];
}

#pragma mark - HTTPMessage (Optional)
- (void)connectionDidClose;
{
    
}

@end