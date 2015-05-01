#import <Foundation/Foundation.h>
#import "HTTPServer.h"
#import "RouteRequest.h"
#import "RouteResponse.h"

@class Route;
@class YapDatabase;

typedef void (^RequestHandler)(RouteRequest *request, RouteResponse *response);

extern NSString *const HTTPMethodGET;
extern NSString *const HTTPMethodPOST;
extern NSString *const HTTPMethodPUT;
extern NSString *const HTTPMethodDELETE;

@interface RoutingHTTPServer : HTTPServer

@property (nonatomic, readonly) NSDictionary *defaultHeaders;
@property (nonatomic, readonly) YapDatabase *database;

- (instancetype)initAtPort:(NSInteger)port
                documentRoot:(NSString *)documentRoot
                databaseName:(NSString *)name;

// Specifies headers that will be set on every response.
// These headers can be overridden by RouteResponses.
- (void)setDefaultHeaders:(NSDictionary *)headers;
- (void)setDefaultHeader:(NSString *)field value:(NSString *)value;

// Returns the dispatch queue on which routes are processed.
// By default this is NULL and routes are processed on CocoaHTTPServer's
// connection queue. You can specify a queue to process routes on, such as
// dispatch_get_main_queue() to process all routes on the main thread.
- (dispatch_queue_t)routeQueue;
- (void)setRouteQueue:(dispatch_queue_t)queue;

- (NSDictionary *)mimeTypes;
- (void)setMIMETypes:(NSDictionary *)types;
- (void)setMIMEType:(NSString *)type forExtension:(NSString *)ext;
- (NSString *)mimeTypeForPath:(NSString *)path;

// Convenience methods. Yes I know, this is Cocoa and we don't use convenience
// methods because typing lengthy primitives over and over and over again is
// elegant with the beauty and the poetry. These are just, you know, here.
- (void)addRoute:(Route *)route;
- (void)addRoute:(Route *)route forMethod:(NSString *)method;

- (BOOL)supportsMethod:(NSString *)method;
- (void)routeMethod:(NSString *)method
           withPath:(NSString *)path
         parameters:(NSDictionary *)params
            request:(HTTPMessage *)httpMessage
         connection:(HTTPConnection *)connection
 andCompletionBlock:(ResponseHandler)completionBlock;
@end
