#import "RoutingHTTPServer.h"
#import "RoutingConnection.h"
#import "Route.h"
#import "YapDatabase.h"

#warning This should be in CocoaHTTPServer.
NSString *const HTTPMethodGET = @"GET";
NSString *const HTTPMethodPOST = @"POST";
NSString *const HTTPMethodPUT = @"PUT";
NSString *const HTTPMethodDELETE = @"DELETE";
NSString *const HTTPMethodHEAD = @"HEAD";

@implementation RoutingHTTPServer {
	NSMutableDictionary *routes;
	NSMutableDictionary *defaultHeaders;
	NSMutableDictionary *mimeTypes;
	dispatch_queue_t routeQueue;
}

@synthesize defaultHeaders;

- (instancetype)initAtPort:(NSInteger)aPort
                documentRoot:(NSString *)aDocumentRoot
                databaseName:(NSString *)databaseName;
{
    if (self != [self init]) {
        return nil;
    }
    
    //It's necessary we use accessor methods.
    [self setPort:(UInt16)aPort];
    [self setDocumentRoot:aDocumentRoot];
    
    NSString *databaseWithFileExtension = [NSString stringWithFormat:@"/database/%@.yap", databaseName];
    NSString *databasePath = [aDocumentRoot stringByAppendingString:databaseWithFileExtension];
    _database = [[YapDatabase alloc] initWithPath:databasePath];
    
    return self;
}

- (id)init {
	if (self = [super init]) {
		connectionClass = [RoutingConnection self];
		routes = [[NSMutableDictionary alloc] init];
		defaultHeaders = [[NSMutableDictionary alloc] init];
		[self setupMIMETypes];
	}
	return self;
}

#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
- (void)dealloc {
	if (routeQueue)
		dispatch_release(routeQueue);
}
#endif

- (void)setDefaultHeaders:(NSDictionary *)headers {
	if (headers) {
		defaultHeaders = [headers mutableCopy];
	} else {
		defaultHeaders = [[NSMutableDictionary alloc] init];
	}
}

- (void)setDefaultHeader:(NSString *)field value:(NSString *)value {
	[defaultHeaders setObject:value forKey:field];
}

- (dispatch_queue_t)routeQueue {
	return routeQueue;
}

- (void)setRouteQueue:(dispatch_queue_t)queue {
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
	if (queue)
		dispatch_retain(queue);

	if (routeQueue)
		dispatch_release(routeQueue);
#endif

	routeQueue = queue;
}

- (NSDictionary *)mimeTypes {
	return mimeTypes;
}

- (void)setMIMETypes:(NSDictionary *)types {
	NSMutableDictionary *newTypes;
	if (types) {
		newTypes = [types mutableCopy];
	} else {
		newTypes = [[NSMutableDictionary alloc] init];
	}

	mimeTypes = newTypes;
}

- (void)setMIMEType:(NSString *)theType forExtension:(NSString *)ext {
	[mimeTypes setObject:theType forKey:ext];
}

- (NSString *)mimeTypeForPath:(NSString *)path {
	NSString *ext = [[path pathExtension] lowercaseString];
	if (!ext || [ext length] < 1)
		return nil;

	return [mimeTypes objectForKey:ext];
}

- (void)addRoute:(Route *)route;
{
    [[route methods] enumerateKeysAndObjectsUsingBlock:^(NSString *method, NSString *key, BOOL *stop) {
        [self addRoute:route
             forMethod:method];
        
        if ([method isEqualToString:HTTPMethodGET]) {
            [self addRoute:route forMethod:HTTPMethodHEAD];
        }
    }];
}

- (void)addRoute:(Route *)route forMethod:(NSString *)method;
{
    method = [method uppercaseString];
    NSMutableArray *methodRoutes = [routes objectForKey:method];
    if (!methodRoutes) {
        methodRoutes = [NSMutableArray array];
        NSAssert(method != nil, @"All Routes should have at least one method implemented");
        [routes setObject:methodRoutes forKey:method];
    }
    
    [methodRoutes addObject:route];
}

- (BOOL)supportsMethod:(NSString *)method {
	return ([routes objectForKey:method] != nil);
}

- (void)handleRoute:(Route *)route
        withRequest:(RouteRequest *)request
           response:(RouteResponse *)response;
{
	if (route.handler) {
        route.handler(request, response);
	} else {
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[route methodSignatureForSelector:route.selector]];
        [inv setSelector:route.selector];
        [inv setTarget:route.target];
        
        [inv setArgument:&(request) atIndex:2]; //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        [inv setArgument:&(response) atIndex:3]; //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        
        [inv invoke];
	}
}

- (void)routeMethod:(NSString *)method
           withPath:(NSString *)path
         parameters:(NSDictionary *)params
            request:(HTTPMessage *)httpMessage
         connection:(HTTPConnection *)connection
 andCompletionBlock:(ResponseHandler)completionBlock;
{
    //Do we have any registered routes?
	NSMutableArray *methodRoutes = [routes objectForKey:method];
    if (!methodRoutes) {
        //Nope. So we can't respond to this request.
        completionBlock(nil, nil);
		return;
    }

    //We do have registered routes. Which one is responsible for this request?
    Route *chosenRoute;
    NSTextCheckingResult *resultForChosenRoute;
	for (Route *route in methodRoutes) {
        NSTextCheckingResult *result = [route isResponsibleForPath:path];
		if (!result)
			continue;
        
        resultForChosenRoute = result;
        chosenRoute = route;
	}
    
    //Did we find someone?
    if (!chosenRoute) {
        //We did not.
        completionBlock(nil, nil);
        return;
    }
    
    //We did find someone responsible.
    //The first range is all of the text matched by the regex.
    NSUInteger captureCount = [resultForChosenRoute numberOfRanges];
    NSArray *routeKeys = chosenRoute.keys[method];
    if (routeKeys) {
        // Add the route's parameters to the parameter dictionary, accounting for
        // the first range containing the matched text.
        if (captureCount == routeKeys.count + 1) {
            NSMutableDictionary *newParams = [params mutableCopy];
            NSUInteger index = 1;
            BOOL firstWildcard = YES;
            for (NSString *key in routeKeys) {
                NSString *capture = [path substringWithRange:[resultForChosenRoute rangeAtIndex:index]];
                if ([key isEqualToString:@"wildcards"]) {
                    NSMutableArray *wildcards = [newParams objectForKey:key];
                    if (firstWildcard) {
                        // Create a new array and replace any existing object with the same key
                        wildcards = [NSMutableArray array];
                        [newParams setObject:wildcards forKey:key];
                        firstWildcard = NO;
                    }
                    [wildcards addObject:capture];
                } else {
                    [newParams setObject:capture forKey:key];
                }
                index++;
            }
            params = newParams;
        }
    } else if (captureCount > 1) {
        // For custom regular expressions place the anonymous captures in the captures parameter
        NSMutableDictionary *newParams = [params mutableCopy];
        NSMutableArray *captures = [NSMutableArray array];
        for (NSUInteger i = 1; i < captureCount; i++) {
            [captures addObject:[path substringWithRange:[resultForChosenRoute rangeAtIndex:i]]];
        }
        [newParams setObject:captures forKey:@"captures"];
        params = newParams;
    }
    
    //Ask for a request and a response from them.
    RouteRequest *request = [[RouteRequest alloc] initWithHTTPMessage:httpMessage parameters:params];
    RouteResponse *response = [[RouteResponse alloc] initWithConnection:connection andResponseBlock:completionBlock];
    if (!routeQueue) {
        [self handleRoute:chosenRoute
              withRequest:request
                 response:response];
    } else {
        // Process the route on the specified queue
        dispatch_sync(routeQueue, ^{
            @autoreleasepool {
                [self handleRoute:chosenRoute
                      withRequest:request
                         response:response];
            }
        });
    }
}

- (void)setupMIMETypes {
	mimeTypes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
				 @"application/x-javascript",   @"js",
				 @"image/gif",                  @"gif",
				 @"image/jpeg",                 @"jpg",
				 @"image/jpeg",                 @"jpeg",
				 @"image/png",                  @"png",
				 @"image/svg+xml",              @"svg",
				 @"image/tiff",                 @"tif",
				 @"image/tiff",                 @"tiff",
				 @"image/x-icon",               @"ico",
				 @"image/x-ms-bmp",             @"bmp",
				 @"text/css",                   @"css",
				 @"text/html",                  @"html",
				 @"text/html",                  @"htm",
				 @"text/plain",                 @"txt",
				 @"text/xml",                   @"xml",
				 nil];
}

@end
