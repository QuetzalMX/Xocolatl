#import "HTTPServer.h"
#import "GCDAsyncSocket.h"
#import "HTTPConnection.h"
#import "WebSocket.h"
#import "HTTPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_INFO; // | HTTP_LOG_FLAG_TRACE;

@interface HTTPServer (PrivateAPI)

- (void)unpublishBonjour;
- (void)publishBonjour;

+ (void)startBonjourThreadIfNeeded;
+ (void)performBonjourBlock:(dispatch_block_t)block;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation HTTPServer

//HTTP Server
@synthesize documentRoot = _documentRoot;
@synthesize connectionClass = _connectionClass;
@synthesize interface = _interface;
@synthesize port = _port;

/**
 * Standard Constructor.
 * Instantiates an HTTP server, but does not start it.
**/
- (instancetype)init;
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		
		// Setup underlying dispatch queues
		serverQueue = dispatch_queue_create("HTTPServer", NULL);
		connectionQueue = dispatch_queue_create("HTTPConnection", NULL);
		
		IsOnServerQueueKey = &IsOnServerQueueKey;
		IsOnConnectionQueueKey = &IsOnConnectionQueueKey;
		
		void *nonNullUnusedPointer = (__bridge void *)self; // Whatever, just not null
		
		dispatch_queue_set_specific(serverQueue, IsOnServerQueueKey, nonNullUnusedPointer, NULL);
		dispatch_queue_set_specific(connectionQueue, IsOnConnectionQueueKey, nonNullUnusedPointer, NULL);
		
		// Initialize underlying GCD based tcp socket
		asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:serverQueue];
		
		// Use default connection class of HTTPConnection
		_connectionClass = [HTTPConnection self];
		
		// By default bind on all available interfaces, en1, wifi etc
		_interface = nil;
		
		// Use a default port of 0
		// This will allow the kernel to automatically pick an open port for us
		_port = 0;
		
		// Configure default values for bonjour service
		
		// Initialize arrays to hold all the HTTP and webSocket connections
		connections = [[NSMutableArray alloc] init];
		webSockets  = [[NSMutableArray alloc] init];
		
		connectionsLock = [[NSLock alloc] init];
		webSocketsLock  = [[NSLock alloc] init];
		
		// Register for notifications of closed connections
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(connectionDidDie:)
		                                             name:HTTPConnectionDidDieNotification
		                                           object:nil];
		
		// Register for notifications of closed websocket connections
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(webSocketDidDie:)
		                                             name:WebSocketDidDieNotification
		                                           object:nil];
		
		isRunning = NO;
	}
	return self;
}

/**
 * Standard Deconstructor.
 * Stops the server, and clients, and releases any resources connected with this instance.
**/
- (void)dealloc
{
	HTTPLogTrace();
    
    [self stop];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[asyncSocket setDelegate:nil delegateQueue:NULL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The document root is filesystem root for the webserver.
 * Thus requests for /index.html will be referencing the index.html file within the document root directory.
 * All file requests are relative to this document root.
**/
- (NSString *)documentRoot;
{
	__block NSString *result;
	
	dispatch_sync(serverQueue, ^{
		result = _documentRoot;
	});
	
	return result;
}

- (void)setDocumentRoot:(NSString *)value;
{
	HTTPLogTrace();
	NSString *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		_documentRoot = valueCopy;
	});
}

/**
 * The connection class is the class that will be used to handle connections.
 * That is, when a new connection is created, an instance of this class will be intialized.
 * The default connection class is HTTPConnection.
 * If you use a different connection class, it is assumed that the class extends HTTPConnection
**/
- (Class)connectionClass;
{
	__block Class result;
	dispatch_sync(serverQueue, ^{
		result = _connectionClass;
	});
	
	return result;
}

- (void)setConnectionClass:(Class)value;
{
	HTTPLogTrace();
	dispatch_async(serverQueue, ^{
		_connectionClass = value;
	});
}

/**
 * What interface to bind the listening socket to.
**/
- (NSString *)interface;
{
	__block NSString *result;
	dispatch_sync(serverQueue, ^{
		result = _interface;
	});
	
	return result;
}

- (void)setInterface:(NSString *)value;
{
	NSString *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		_interface = valueCopy;
	});
}

/**
 * The port to listen for connections on.
 * By default this port is initially set to zero, which allows the kernel to pick an available port for us.
 * After the HTTP server has started, the port being used may be obtained by this method.
**/
- (NSUInteger)port;
{
	__block UInt16 result;
	dispatch_sync(serverQueue, ^{
		result = _port;
	});
	
    return result;
}

- (NSUInteger)listeningPort;
{
	__block UInt16 result;
	dispatch_sync(serverQueue, ^{
        result = (isRunning) ? [asyncSocket localPort] : 0;
	});
	
	return result;
}

- (void)setPort:(NSUInteger)value;
{
	HTTPLogTrace();
	
	dispatch_async(serverQueue, ^{
		_port = value;
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Control
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)start:(NSError **)errPtr
{
	HTTPLogTrace();
	
	__block BOOL success = YES;
	__block NSError *err = nil;
	
	dispatch_sync(serverQueue, ^{ @autoreleasepool {
		
		success = [asyncSocket acceptOnInterface:self.interface
                                            port:self.port
                                           error:&err];
		if (success)
		{
			HTTPLogInfo(@"%@: Started HTTP server on port %hu", THIS_FILE, [asyncSocket localPort]);
			
			isRunning = YES;
			[self publishBonjour];
		}
		else
		{
			HTTPLogError(@"%@: Failed to start HTTP Server: %@", THIS_FILE, err);
		}
	}});
	
	if (errPtr)
		*errPtr = err;
	
	return success;
}

- (void)stop
{
	[self stop:NO];
}

- (void)stop:(BOOL)keepExistingConnections
{
	HTTPLogTrace();
	
	dispatch_sync(serverQueue, ^{ @autoreleasepool {
		
		// First stop publishing the service via bonjour
		[self unpublishBonjour];
		
		// Stop listening / accepting incoming connections
		[asyncSocket disconnect];
		isRunning = NO;
		
		if (!keepExistingConnections)
		{
			// Stop all HTTP connections the server owns
			[connectionsLock lock];
			for (HTTPConnection *connection in connections)
			{
				[connection stop];
			}
			[connections removeAllObjects];
			[connectionsLock unlock];
			
			// Stop all WebSocket connections the server owns
			[webSocketsLock lock];
			for (WebSocket *webSocket in webSockets)
			{
				[webSocket stop];
			}
			[webSockets removeAllObjects];
			[webSocketsLock unlock];
		}
	}});
}

- (BOOL)isRunning
{
	__block BOOL result;
	
	dispatch_sync(serverQueue, ^{
		result = isRunning;
	});
	
	return result;
}

- (void)addWebSocket:(WebSocket *)ws
{
	[webSocketsLock lock];
	
	HTTPLogTrace();
	[webSockets addObject:ws];
	
	[webSocketsLock unlock];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Status
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the number of http client connections that are currently connected to the server.
**/
- (NSUInteger)numberOfHTTPConnections
{
	NSUInteger result = 0;
	
	[connectionsLock lock];
	result = [connections count];
	[connectionsLock unlock];
	
	return result;
}

/**
 * Returns the number of websocket client connections that are currently connected to the server.
**/
- (NSUInteger)numberOfWebSocketConnections
{
	NSUInteger result = 0;
	
	[webSocketsLock lock];
	result = [webSockets count];
	[webSocketsLock unlock];
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Incoming Connections
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (HTTPConfig *)config
{
	// Override me if you want to provide a custom config to the new connection.
	// 
	// Generally this involves overriding the HTTPConfig class to include any custom settings,
	// and then having this method return an instance of 'MyHTTPConfig'.
	
	// Note: Think you can make the server faster by putting each connection on its own queue?
	// Then benchmark it before and after and discover for yourself the shocking truth!
	// 
	// Try the apache benchmark tool (already installed on your Mac):
	// $  ab -n 1000 -c 1 http://localhost:<port>/some_path.html
	
	return [[HTTPConfig alloc] initWithServer:self
                                 documentRoot:self.documentRoot
                                        queue:connectionQueue];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	HTTPConnection *newConnection = (HTTPConnection *)[[self.connectionClass alloc] initWithAsyncSocket:newSocket
                                                                                          configuration:[self config]];
	[connectionsLock lock];
	[connections addObject:newConnection];
	[connectionsLock unlock];
	
	[newConnection start];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is automatically called when a notification of type HTTPConnectionDidDieNotification is posted.
 * It allows us to remove the connection from our array.
**/
- (void)connectionDidDie:(NSNotification *)notification
{
	// Note: This method is called on the connection queue that posted the notification
	
	[connectionsLock lock];
	
	HTTPLogTrace();
	[connections removeObject:[notification object]];
	
	[connectionsLock unlock];
}

/**
 * This method is automatically called when a notification of type WebSocketDidDieNotification is posted.
 * It allows us to remove the websocket from our array.
**/
- (void)webSocketDidDie:(NSNotification *)notification
{
	// Note: This method is called on the connection queue that posted the notification
	
	[webSocketsLock lock];
	
	HTTPLogTrace();
	[webSockets removeObject:[notification object]];
	
	[webSocketsLock unlock];
}

@end
