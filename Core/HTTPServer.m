//
//  HTTPServer.m
//  CocoaHTTPServer
//
//  Created by Robbie Hanson

#import "HTTPServer.h"
#import "GCDAsyncSocket.h"
#import "HTTPConnection.h"
#import "WebSocket.h"
#import "HTTPLogging.h"
#import "HTTPConfig.h"

static const int httpLogLevel = HTTP_LOG_LEVEL_INFO;

@interface HTTPServer ()
{
    // Underlying asynchronous TCP/IP socket
    GCDAsyncSocket *asyncSocket;

    dispatch_queue_t connectionQueue;
    void *IsOnServerQueueKey;
    void *IsOnConnectionQueueKey;
    
    // Connection management
    NSMutableArray *connections;
    NSMutableArray *webSockets;
    NSLock *connectionsLock;
    NSLock *webSocketsLock;
}

@property (nonatomic, readwrite) BOOL isRunning;
@property (nonatomic, weak) id <HTTPServerDelegate> delegate;

@end

@implementation HTTPServer

//HTTP Server
@synthesize documentRoot = _documentRoot;
@synthesize interface = _interface;
@synthesize port = _port;

- (instancetype)initWithDelegate:(id<HTTPServerDelegate>)delegate;
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		
		// Setup underlying dispatch queues
		_serverQueue = dispatch_queue_create("HTTPServer", NULL);
		connectionQueue = dispatch_queue_create("HTTPConnection", NULL);
		
		IsOnServerQueueKey = &IsOnServerQueueKey;
		IsOnConnectionQueueKey = &IsOnConnectionQueueKey;
		
		void *nonNullUnusedPointer = (__bridge void *)self; // Whatever, just not null
		
		dispatch_queue_set_specific(_serverQueue, IsOnServerQueueKey, nonNullUnusedPointer, NULL);
		dispatch_queue_set_specific(connectionQueue, IsOnConnectionQueueKey, nonNullUnusedPointer, NULL);
		
		// Initialize underlying GCD based tcp socket
		asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_serverQueue];
		
		// By default bind on all available interfaces, en1, wifi etc
		_interface = nil;
		
		// Use a default port of 0
		// This will allow the kernel to automatically pick an open port for us
		_port = 0;
        
        _delegate = delegate;
		
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
		
		_isRunning = NO;
	}
	return self;
}

- (void)dealloc
{
	HTTPLogTrace();
    
    [self stop:NO];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[asyncSocket setDelegate:nil delegateQueue:NULL];
}

#pragma mark Server Configuration
- (BOOL)isOnServerQueue;
{
    return (dispatch_get_specific(IsOnServerQueueKey) != NULL);
}

- (NSString *)documentRoot;
{
	__block NSString *result;
	dispatch_sync(self.serverQueue, ^{
		result = _documentRoot;
	});
	
	return result;
}

- (void)setDocumentRoot:(NSString *)value;
{
	HTTPLogTrace();
	NSString *valueCopy = [value copy];
	dispatch_async(self.serverQueue, ^{
		_documentRoot = valueCopy;
	});
}

- (NSString *)interface;
{
	__block NSString *result;
	dispatch_sync(self.serverQueue, ^{
		result = _interface;
	});
	
	return result;
}

- (void)setInterface:(NSString *)value;
{
	NSString *valueCopy = [value copy];
	dispatch_async(self.serverQueue, ^{
		_interface = valueCopy;
	});
}

- (NSUInteger)port;
{
	__block UInt16 result;
	dispatch_sync(self.serverQueue, ^{
		result = _port;
	});
	
    return result;
}

- (NSUInteger)listeningPort;
{
	__block UInt16 result;
	dispatch_sync(self.serverQueue, ^{
        result = (self.isRunning) ? [asyncSocket localPort] : 0;
	});
	
	return result;
}

- (void)setPort:(NSUInteger)value;
{
	HTTPLogTrace();
	dispatch_async(self.serverQueue, ^{
		_port = value;
	});
}

#pragma mark Server Control
- (BOOL)start:(NSError **)errPtr
{
	HTTPLogTrace();
	
	__block BOOL success = YES;
	dispatch_sync(self.serverQueue, ^{ @autoreleasepool {
		
		self.isRunning = [asyncSocket acceptOnInterface:self.interface
                                                   port:self.port
                                                  error:errPtr];
		if (self.isRunning)
		{
			HTTPLogInfo(@"%@: Started HTTP server on port %hu", THIS_FILE, [asyncSocket localPort]);
		}
		else
		{
			HTTPLogError(@"%@: Failed to start HTTP Server: %@", THIS_FILE, *errPtr);
		}
        
        success = self.isRunning;
	}});
	
	return success;
}

- (void)stop:(BOOL)keepExistingConnections
{
	HTTPLogTrace();
	dispatch_sync(self.serverQueue, ^{ @autoreleasepool {
		
		// Stop listening / accepting incoming connections
		[asyncSocket disconnect];
		self.isRunning = NO;
        
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
	dispatch_sync(self.serverQueue, ^{
		result = _isRunning;
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

#pragma mark Server Status
- (NSUInteger)numberOfHTTPConnections;
{
	NSUInteger result = 0;
	
	[connectionsLock lock];
	result = [connections count];
	[connectionsLock unlock];
	
	return result;
}

- (NSUInteger)numberOfWebSocketConnections;
{
	NSUInteger result = 0;
    
	[webSocketsLock lock];
	result = [webSockets count];
	[webSocketsLock unlock];
	
	return result;
}

#pragma mark Incoming Connections
- (HTTPConfig *)config;
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

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;
{
    HTTPConnection *newConnection = [self.delegate connectionForSocket:newSocket];

	[connectionsLock lock];
	[connections addObject:newConnection];
	[connectionsLock unlock];
	
	[newConnection start];
}

#pragma mark Notifications
- (void)connectionDidDie:(NSNotification *)notification;
{
	[connectionsLock lock];
	HTTPLogTrace();
	[connections removeObject:[notification object]];
	[connectionsLock unlock];
}

- (void)webSocketDidDie:(NSNotification *)notification
{
	[webSocketsLock lock];
	HTTPLogTrace();
	[webSockets removeObject:[notification object]];
	[webSocketsLock unlock];
}

@end
