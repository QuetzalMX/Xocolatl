#import "RoutingHTTPServer.h"
#import "RoutingConnection.h"
#import "RoutingResponder.h"
#import "RoutingResponse.h"

@interface RoutingHTTPServer () {
    NSMutableDictionary *_mutableDefaultHeaders;
    NSMutableDictionary *_mutableMIMETypes;
}

@property (nonatomic, strong) NSMutableDictionary *responders;

@end

@implementation RoutingHTTPServer

- (instancetype)initAtPort:(NSInteger)aPort;
{
	if (self != [super init]) {
        return nil;
    }
    
    //Pass the HTTPServer our connection class.
    //This means that all incoming connections will be represented by objects of this class.
    connectionClass = [RoutingConnection class];
    
    //It's necessary we use accessor methods because we don't want to modify our super class.
    [self setPort:(UInt16)aPort];
    
    _responders = [[NSMutableDictionary alloc] init];
    _mutableDefaultHeaders = [[NSMutableDictionary alloc] init];
    _mimeTypes = @{ @"js": @"application/x-javascript",
                    @"gif": @"image/gif",
                    @"jpg": @"image/jpeg",
                    @"jpeg": @"image/jpeg",
                    @"png": @"image/png",
                    @"svg": @"image/svg+xml",
                    @"tif": @"image/tiff",
                    @"tiff": @"image/tiff",
                    @"ico": @"image/x-icon",
                    @"bmp": @"image/x-ms-bmp",
                    @"css": @"text/css",
                    @"html": @"text/html",
                    @"htm": @"text/html",
                    @"txt": @"text/plain",
                    @"xml": @"text/xml"};
    
    return self;
}

#pragma mark - Default Headers
- (void)setDefaultHeaders:(NSDictionary *)defaultHeaders;
{
    _mutableDefaultHeaders = [defaultHeaders mutableCopy];
}

- (NSDictionary *)defaultHeaders;
{
    return [_mutableDefaultHeaders copy];
}

- (void)setDefaultHeader:(NSString *)field value:(NSString *)value;
{
    _mutableDefaultHeaders[field] = value;
}

#pragma mark - MIME Types
- (void)setMIMETypes:(NSDictionary *)types;
{
    _mutableMIMETypes = [types mutableCopy];
}

- (NSDictionary *)mimeTypes;
{
	return [_mutableMIMETypes copy];
}

- (void)setMIMEType:(NSString *)theType forExtension:(NSString *)ext;
{
	_mutableMIMETypes[ext] = theType;
}

- (NSString *)mimeTypeForPath:(NSString *)path;
{
	return _mutableMIMETypes[path.pathExtension.lowercaseString];
}

#pragma mark - Routing
- (void)addResponseHandler:(RoutingResponder *)responder;
{
    //A HEAD request is the same as a GET request, but it responds with headers only.
    NSMutableDictionary *responderMethods = [responder.methods mutableCopy];
    if (responder.methods[@"GET"]) {
        responderMethods[@"HEAD"] = responder.methods[@"GET"];
    }
    
    //A new handler can have multiple methods and paths.
    //e.g. SignInResponseHandler can handle a GET for a sign in webpage and a POST to a different path for the sign in action.
    //They cannot have repeated methods.
    [responderMethods enumerateKeysAndObjectsUsingBlock:^(NSString *method, NSString *path, BOOL *stop) {
        
        
        //Register this handler for the given method.
        NSMutableArray *respondersForMethod = self.responders[method.uppercaseString];
        if (!respondersForMethod) {
            //This is our first responder for this method.
            respondersForMethod = [NSMutableArray new];
            self.responders[method.uppercaseString] = respondersForMethod;
        }
        
        [respondersForMethod addObject:responder];
    }];
}

- (BOOL)supportsMethod:(NSString *)method;
{
    return (self.responders[method.uppercaseString] != nil);
}

#pragma mark RoutingConnectionDelegate
- (RoutingResponse *)connection:(HTTPConnection *)connection
        didFinishReadingRequest:(HTTPMessage *)request
                       withPath:(NSString *)path
                         method:(NSString *)method
                  andParameters:(NSDictionary *)parameters;
{
    //RoutingConnection just finished reading all the necessary data from a request (this request has already been authorized).
    //Now, RoutingConnection is requesting a response from us.
    //What we need to do is find out what the path/method combination is and find a responseHandler that can process our request.
    //Once we have it, we pass the response back to RoutingConnection so that it can answer the request.
    //Categories seem like a good way of getting a response handler, but that might pose some problems with connections.
    //Perhaps we have a set of connections in the routingServer?
    
    //Who needs to handle this response?
    NSMutableArray *respondersForMethod = self.responders[method];
    if (!respondersForMethod || respondersForMethod.count <= 0) {
        //We don't know of anyone who can handle this response.
        return nil;
    }
    
    __block RoutingResponder *responsibleResponder;
    NSMutableDictionary *newParams = [parameters mutableCopy];
    [respondersForMethod enumerateObjectsUsingBlock:^(RoutingResponder *responder, NSUInteger idx, BOOL *stop) {
        //This responder recognizes the method. Does it recognize the path?
        NSTextCheckingResult *result = [[responder regexForMethod:method] firstMatchInString:path
                                                                                     options:0
                                                                                       range:NSMakeRange(0, path.length)];
        if (!result) {
            //Note: (FO) A regex will not return a result if there are no values in any captured group.
            //This does not mean that the responder is not responsible, it only means that there were no arguments passed when they were probably expected.
            //Perhaps it's the path without any matching capture groups?
            //e.g. /api/teams/:id
            //being called using
            // /api/teams/
            // I'm assuming we're not responsible of sanitizing inputs, so if the path is contained in the responder's path for this method, let it through.
            NSString *responderPath = responder.methods[method];
            if ([responderPath containsString:path]) {
                //It is matching without any regex.
                responsibleResponder = responder;
                *stop = YES;
            }
            
            //It didn't recognize the path or the regex. This isn't the responsible responder.
            return;
        }
        
        // The first range is all of the text matched by the regex.
        NSUInteger captureCount = [result numberOfRanges];
        NSArray *responderKeys = [responder keysForMethod:method];
        
        if (responderKeys) {
            // Add the route's parameters to the parameter dictionary, accounting for
            // the first range containing the matched text.
            if (captureCount == responderKeys.count + 1) {
                __block NSUInteger index = 1;
                __block BOOL firstWildcard = YES;
                
                [responderKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
                    NSString *capture = [path substringWithRange:[result rangeAtIndex:index]];
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
                }];
            }
        } else if (captureCount > 1) {
            // For custom regular expressions place the anonymous captures in the captures parameter
            NSMutableDictionary *newParams = [parameters mutableCopy];
            NSMutableArray *captures = [NSMutableArray array];
            for (NSUInteger i = 1; i < captureCount; i++) {
                [captures addObject:[path substringWithRange:[result rangeAtIndex:i]]];
            }
            [newParams setObject:captures forKey:@"captures"];
        }
        
        responsibleResponder = responder;
        *stop = YES;
    }];
    
    return [responsibleResponder responseForRequest:request
                                     withParameters:newParams];;
}

@end
