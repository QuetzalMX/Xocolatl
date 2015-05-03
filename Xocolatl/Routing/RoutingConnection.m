#import "RoutingConnection.h"
#import "RoutingHTTPServer.h"
#import "HTTPMessage.h"
#import "RoutingResponse.h"

//Authentication
#import "GCDAsyncSocket.h"
#import "HTTPMessage.h"
#import "XOCUser+Auth.h"

@interface RoutingConnection ()

@property (nonatomic, assign) RoutingHTTPServer *delegate;

@end

@implementation RoutingConnection {
	NSDictionary *headers;
}

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket
            configuration:(HTTPConfig *)aConfig;
{
	if (self != [super initWithAsyncSocket:newSocket configuration:aConfig]) {
        return nil;
    }
    
    NSAssert([config.server isKindOfClass:[RoutingHTTPServer class]],
             @"A RoutingConnection is being used with a server that is not a RoutingHTTPServer");

    _delegate = (RoutingHTTPServer *)config.server;
	
	return self;
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path {

	if ([self.delegate supportsMethod:method])
		return YES;

	return [super supportsMethod:method atPath:path];
}

- (BOOL)shouldHandleRequestForMethod:(NSString *)method atPath:(NSString *)path {
	// The default implementation is strict about the use of Content-Length. Either
	// a given method + path combination must *always* include data or *never*
	// include data. The routing connection is lenient, a POST that sometimes does
	// not include data or a GET that sometimes does is fine. It is up to the route
	// implementations to decide how to handle these situations.
	return YES;
}

- (void)processBodyData:(NSData *)postDataChunk {
	BOOL result = [request appendData:postDataChunk];
	if (!result) {
		// TODO: Log
	}
}

- (void)setHeadersForResponse:(HTTPMessage *)response isError:(BOOL)isError;
{
	[self.delegate.defaultHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL *stop) {
		[response setHeaderField:field value:value];
	}];

	if (headers && !isError) {
		[headers enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL *stop) {
			[response setHeaderField:field value:value];
		}];
	}

	// Set the connection header if not already specified
	NSString *connection = [response headerField:@"Connection"];
	if (!connection) {
		connection = [self shouldDie] ? @"close" : @"keep-alive";
		[response setHeaderField:@"Connection" value:connection];
	}
}

- (NSData *)preprocessResponse:(HTTPMessage *)response {
	[self setHeadersForResponse:response isError:NO];
	return [super preprocessResponse:response];
}

- (NSData *)preprocessErrorResponse:(HTTPMessage *)response {
	[self setHeadersForResponse:response isError:YES];
	return [super preprocessErrorResponse:response];
}

- (BOOL)shouldDie;
{
	__block BOOL shouldDie = [super shouldDie];

	// Allow custom headers to determine if the connection should be closed
	if (!shouldDie && headers) {
		[headers enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL *stop) {
			if ([field caseInsensitiveCompare:@"connection"] == NSOrderedSame) {
				if ([value caseInsensitiveCompare:@"close"] == NSOrderedSame) {
					shouldDie = YES;
				}
				*stop = YES;
			}
		}];
	}

	return shouldDie;
}

#pragma mark - HTTPResponse
- (NSObject <HTTPResponse> *)httpResponseForMethod:(NSString *)method
                                              URI:(NSString *)path;
{
    //We just received a connection.
    NSURL *url = [request url];
    NSString *query = nil;
    NSDictionary *params = [NSDictionary dictionary];
    headers = nil;
    
    if (url) {
        path = [url path]; // Strip the query string from the path
        query = [url query];
        if (query) {
            params = [self parseParams:query];
        }
    }
    
    RoutingResponse *response = [self.delegate connection:self
                                  didFinishReadingRequest:request
                                                 withPath:path
                                                   method:method
                                            andParameters:params];
    if (!response) {
        //We didn't know how to handle it. Perhaps HTTPConnection knows?
        return [super httpResponseForMethod:method
                                        URI:path];
    }
    
    headers = response.httpHeaders;
    return response;
}

@end