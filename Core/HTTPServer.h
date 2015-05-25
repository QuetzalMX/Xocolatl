//
//  HTTPServer.h
//  CocoaHTTPServer
//
//  Created by Robbie Hanson

#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class WebSocket;

@class HTTPConnection;
@protocol HTTPServerDelegate

- (HTTPConnection *)connectionForSocket:(GCDAsyncSocket *)socket;

@end

@interface HTTPServer : NSObject <NSNetServiceDelegate>

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, strong, readonly) dispatch_queue_t serverQueue;
@property (nonatomic, readonly) BOOL isOnServerQueue;

/**
 * Specifies the document root to serve files from.
 * For example, if you set this to "/Users/<your_username>/Sites",
 * then it will serve files out of the local Sites directory (including subdirectories).
 * 
 * The default value is nil.
 * The default server configuration will not serve any files until this is set.
 * 
 * If you change the documentRoot while the server is running,
 * the change will affect future incoming http connections.
**/
@property (nonatomic, copy) NSString *documentRoot;

/**
 * Set what interface you'd like the server to listen on.
 * By default this is nil, which causes the server to listen on all available interfaces like en1, wifi etc.
 * 
 * The interface may be specified by name (e.g. "en1" or "lo0") or by IP address (e.g. "192.168.4.34").
 * You may also use the special strings "localhost" or "loopback" to specify that
 * the socket only accept connections from the local machine.
**/
@property (nonatomic, copy) NSString *interface;

/**
 * The port number to run the HTTP server on.
 * 
 * The default port number is zero, meaning the server will automatically use any available port.
 * This is the recommended port value, as it avoids possible port conflicts with other applications.
 * Technologies such as Bonjour can be used to allow other applications to automatically discover the port number.
 * 
 * Note: As is common on most OS's, you need root privleges to bind to port numbers below 1024.
 * 
 * You can change the port property while the server is running, but it won't affect the running server.
 * To actually change the port the server is listening for connections on you'll need to restart the server.
 * 
 * The listeningPort method will always return the port number the running server is listening for connections on.
 * If the server is not running this method returns 0.
**/
@property (nonatomic) NSUInteger port;
@property (nonatomic, readonly) NSUInteger listeningPort;

- (instancetype)initWithDelegate:(id <HTTPServerDelegate>)delegate;

/**
 * Attempts to starts the server on the configured port, interface, etc.
 * 
 * If an error occurs, this method returns NO and sets the errPtr (if given).
 * Otherwise returns YES on success.
 * 
 * Some examples of errors that might occur:
 * - You specified the server listen on a port which is already in use by another application.
 * - You specified the server listen on a port number below 1024, which requires root priviledges.
 * 
 * Code Example:
 * 
 * NSError *err = nil;
 * if (![httpServer start:&err])
 * {
 *     NSLog(@"Error starting http server: %@", err);
 * }
**/
- (BOOL)start:(NSError **)errPtr;

- (void)stop:(BOOL)keepExistingConnections;

- (void)addWebSocket:(WebSocket *)ws;

- (NSUInteger)numberOfHTTPConnections;
- (NSUInteger)numberOfWebSocketConnections;

@end
