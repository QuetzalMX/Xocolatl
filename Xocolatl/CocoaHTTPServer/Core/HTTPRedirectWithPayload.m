//
//  HTTPRedirectWithPayload.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/16/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPRedirectWithPayload.h"
#import "HTTPLogging.h"

static const int httpLogLevel = HTTP_LOG_LEVEL_OFF; // | HTTP_LOG_FLAG_TRACE;

@interface HTTPRedirectWithPayload ()

@property (nonatomic, copy) NSString *destination;

@end

@implementation HTTPRedirectWithPayload

- (instancetype)initWithData:(NSData *)someData
              andDestination:(NSString *)destination;
{
    if (self != [super initWithData:someData]) {
        return nil;
    }
    
    _destination = destination;
    
    return self;
}

- (NSDictionary *)httpHeaders
{
    HTTPLogTrace();
    
    return [NSDictionary dictionaryWithObject:self.destination forKey:@"Location"];
}

- (NSInteger)status
{
    HTTPLogTrace();
    
    return 302;
}

- (void)dealloc
{
    HTTPLogTrace();
    
}

@end
