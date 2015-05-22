//
//  BonjourHTTPServer.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/22/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <XocolatlFramework/XocolatlFramework.h>

@interface BonjourHTTPServer : HTTPServer

/**
 * Bonjour domain for publishing the service.
 * The default value is "local.".
 *
 * Note: Bonjour publishing requires you set a type.
 *
 * If you change the domain property after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
 **/
@property (nonatomic, copy) NSString *domain;

/**
 * Bonjour name for publishing the service.
 * The default value is "".
 *
 * If using an empty string ("") for the service name when registering,
 * the system will automatically use the "Computer Name".
 * Using an empty string will also handle name conflicts
 * by automatically appending a digit to the end of the name.
 *
 * Note: Bonjour publishing requires you set a type.
 *
 * If you change the name after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
 *
 * The publishedName method will always return the actual name that was published via the bonjour service.
 * If the service is not running this method returns nil.
 **/
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, readonly) NSString *publishedName;

/**
 * Bonjour type for publishing the service.
 * The default value is nil.
 * The service will not be published via bonjour unless the type is set.
 *
 * If you wish to publish the service as a traditional HTTP server, you should set the type to be "_http._tcp.".
 *
 * If you change the type after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
 **/
@property (nonatomic, copy) NSString *type;

/**
 * Republishes the service via bonjour if the server is running.
 * If the service was not previously published, this method will publish it (if the server is running).
 **/
- (void)republishBonjour;

@end
