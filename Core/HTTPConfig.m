//
//  HTTPConfig.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPConfig.h"

#import "HTTPServer.h"

@implementation HTTPConfig

- (instancetype)initWithServer:(HTTPServer *)server
                  documentRoot:(NSString *)documentRoot;
{
    if ((self = [super init]))
    {
        _server = server;
        _documentRoot = documentRoot;
    }
    return self;
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
        
        if (q)
        {
            _queue = q;
        }
    }
    return self;
}

@end