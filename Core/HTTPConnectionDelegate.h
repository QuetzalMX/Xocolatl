//
//  HTTPConnectionDelegate.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#ifndef Xocolatl_HTTPConnectionDelegate_h
#define Xocolatl_HTTPConnectionDelegate_h

@class NSDateFormatter;
@class HTTPMessage;
@class HTTPConnection;
@class WebSocket;

@protocol HTTPResponse;

/**
 *  HTTPConnectionDelegate is in charge of the lifecycle of an HTTPConnection, its errors and reading any data that comes along with a request.
 
    All methods here are optional.
 */
@protocol HTTPConnectionDelegate

@optional
- (NSDateFormatter *)connectionDateFormatter;

//Lifecycle
- (void)connectionWillStart:(HTTPConnection *)connection;
- (void)connection:(HTTPConnection *)connection didSendResponse:(NSObject<HTTPResponse> *)response;
- (void)connectionWillDie:(HTTPConnection *)connection;

//Errors
- (HTTPMessage *)connection:(HTTPConnection *)connection responseForMalformedRequest:(NSData *)data;
- (HTTPMessage *)connection:(HTTPConnection *)connection responseForUnsupportedHTTPVersion:(NSString *)unsupportedVersion;
- (HTTPMessage *)connection:(HTTPConnection *)connection responseForResourceNotFound:(HTTPMessage *)request;
- (void)connection:(HTTPConnection *)connection willSendErrorResponse:(HTTPMessage *)errorResponse;

//Data
- (void)connection:(HTTPConnection *)connection willReadBodyOfSize:(NSUInteger)bodySize;
- (BOOL)connection:(HTTPConnection *)connection shouldAppendData:(NSData *)data;
- (void)connection:(HTTPConnection *)connection didReadBodyOfSize:(NSUInteger)bodySize;

@end

typedef NS_ENUM(NSUInteger, HTTPConnectionSecurityAuthenticationType) {
    HTTPConnectionSecurityAuthenticationTypeNone,
    HTTPConnectionSecurityAuthenticationTypeBasic,
    HTTPConnectionSecurityAuthenticationTypeDigest,
    HTTPConnectionSecurityAuthenticationTypeCookie,
};

@protocol HTTPConnectionSecurityDelegate

@optional
- (NSArray *)sslIdentityAndCertificates;
- (NSString *)authenticationRealmForConnection:(HTTPConnection *)connection;

- (HTTPConnectionSecurityAuthenticationType)connection:(HTTPConnection *)connection authLevelForPath:(NSString *)path;
- (NSString *)connection:(HTTPConnection *)connection passwordForUser:(NSString *)user;
- (BOOL)connection:(HTTPConnection *)connection validateCredentialsForAccessToPath:(NSString *)path withAccessLevel:(HTTPConnectionSecurityAuthenticationType)authenticationType;

- (HTTPMessage *)connection:(HTTPConnection *)connection
failedToAuthenticateForPath:(NSString *)path
            withAccessLevel:(HTTPConnectionSecurityAuthenticationType)authenticationType;
@end

@protocol HTTPConnectionRoutingDelegate

@optional
- (BOOL)connection:(HTTPConnection *)connection expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path;
- (BOOL)connection:(HTTPConnection *)connection
     supportsMethod:(NSString *)method
            atPath:(NSString *)path;

- (NSObject<HTTPResponse> *)responseForConnection:(HTTPConnection *)connection;

- (void)connection:(HTTPConnection *)connection willRespondUsing:(HTTPMessage *)response;

- (HTTPMessage *)connection:(HTTPConnection *)connection
   responseForUnknownMethod:(NSString *)method
                     atPath:(NSString *)path;

@end

@protocol HTTPConnectionWebSocketDelegate <NSObject>

- (WebSocket *)connectionWillTransitionToSocket:(HTTPConnection *)connection;
- (void)socketDidDisconnect;

@end

#endif
