//
//  HTTPConfig.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.

#import <Foundation/Foundation.h>

@class HTTPServer;

@interface HTTPConfig : NSObject

@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, weak, readonly) HTTPServer *server;
@property (nonatomic, strong, readonly) NSString *documentRoot;

- (instancetype)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot;
- (instancetype)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot queue:(dispatch_queue_t)q;

@end