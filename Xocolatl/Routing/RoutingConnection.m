#import "RoutingConnection.h"
#import "RoutingHTTPServer.h"
#import "HTTPMessage.h"
#import "HTTPResponseProxy.h"

@interface RoutingConnection ()

@property (nonatomic, weak) RoutingHTTPServer *http;
@property (nonatomic, copy) NSDictionary *headers;

@end

@implementation RoutingConnection

- (instancetype)initWithAsyncSocket:(GCDAsyncSocket *)newSocket
                      configuration:(HTTPConfig *)aConfig;
{
	if (self != [super initWithAsyncSocket:newSocket configuration:aConfig]) {
        return nil;
	}
    
    NSAssert([config.server isKindOfClass:[RoutingHTTPServer class]], @"A RoutingConnection is being used with a server that is not a RoutingHTTPServer");
    _http = (RoutingHTTPServer *)config.server;
    
	return self;
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path {

	if ([self.http supportsMethod:method])
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
	[request appendData:postDataChunk];
}

- (void)httpResponseForMethod:(NSString *)method
                          URI:(NSString *)path
           andCompletionBlock:(void (^)(NSObject <HTTPResponse> *))completionBlock;
{
    //We need to find a response for this method.
    //Pass it to our router, who will find the route that's responsible.
    [self.http routeMethod:method
                  withPath:request.url.path
                parameters:[self parseParams:request.url.query]
                   request:request
                connection:self
        andCompletionBlock:^(NSObject<HTTPResponse> *response, NSDictionary *responseHeaders) {
            //Someone did end up being responsible. We're done.
            if (response) {
                self.headers = responseHeaders;
                completionBlock(response);
                return;
            }
       
            //No one was responsible for this route.
            //Attempt to send a static file.
            [super httpResponseForMethod:method
                                     URI:path
                      andCompletionBlock:^ (NSObject <HTTPResponse> *staticResponse) {
#warning I need to check what this was for.
//                          if (staticResponse && [staticResponse respondsToSelector:@selector(filePath)]) {
//                              NSString *mimeType = [self.http mimeTypeForPath:[staticResponse performSelector:@selector(filePath)]];
//                              if (mimeType) {
//                                  self.headers = [NSDictionary dictionaryWithObject:mimeType forKey:@"Content-Type"];
//                              }
//                          }
                     
                          completionBlock(staticResponse);
                      }];
   }];
	
}

- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender;
{
    if ([sender respondsToSelector:@selector(response)]) {
        HTTPResponseProxy *proxy = (HTTPResponseProxy *)httpResponse;
        if (proxy.response == sender) {
            [super responseHasAvailableData:httpResponse];
        }
    } else {
        [super responseHasAvailableData:sender];
    }
}

- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender {
	HTTPResponseProxy *proxy = (HTTPResponseProxy *)httpResponse;
	if (proxy.response == sender) {
		[super responseDidAbort:httpResponse];
	}
}

- (void)setHeadersForResponse:(HTTPMessage *)response isError:(BOOL)isError {
	[self.http.defaultHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL *stop) {
        [response setHeaderField:field value:value];
	}];

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

- (BOOL)shouldDie {
	__block BOOL shouldDie = [super shouldDie];

	// Allow custom headers to determine if the connection should be closed
	if (!shouldDie && self.headers) {
		[self.headers enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL *stop) {
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

@end
