//
//  HTTPConfig.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.

#import "HTTPConfig.h"

#import "HTTPServer.h"

@implementation HTTPConfig

- (instancetype)initWithServer:(HTTPServer *)server
                  documentRoot:(NSString *)documentRoot;
{
    return [self initWithServer:server
                   documentRoot:documentRoot
                          queue:nil];
}

- (instancetype)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot queue:(dispatch_queue_t)q;
{
    if ((self = [super init]))
    {
        _server = server;
        
        _documentRoot = [documentRoot stringByStandardizingPath];
        if ([_documentRoot hasSuffix:@"/"])
        {
            _documentRoot = [_documentRoot stringByAppendingString:@"/"];
        }
        
        _queue = q ?: nil;
    }
    return self;
}

@end