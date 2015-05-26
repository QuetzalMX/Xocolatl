//
//  HTTPConnection.h
//  CocoaHTTPServer
//
//  Created by Robbie Hanson.

#import <Foundation/Foundation.h>
#import "HTTPConnectionDelegate.h"

@class GCDAsyncSocket;
@class HTTPMessage;
@class HTTPServer;
@class HTTPConfig;
@class WebSocket;

@protocol HTTPResponse;

extern NSString *const HTTPConnectionDidDieNotification;

@interface HTTPConnection : NSObject

@property (nonatomic, weak) id <HTTPConnectionDelegate> delegate;
@property (nonatomic, weak) id <HTTPConnectionRoutingDelegate> routingDelegate;
@property (nonatomic, weak) id <HTTPConnectionSecurityDelegate> securityDelegate;
@property (nonatomic, weak) id <HTTPConnectionWebSocketDelegate> socketDelegate;

@property (nonatomic, strong, readonly) HTTPConfig *config;
@property (nonatomic, strong, readonly) HTTPMessage *request;
@property (nonatomic, strong) NSObject <HTTPResponse> *httpResponse;

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig;

- (void)start;
- (void)stop;

- (NSString *)requestURI;

@end

@interface HTTPConnection (AsynchronousHTTPResponse)
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender;
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender;
@end