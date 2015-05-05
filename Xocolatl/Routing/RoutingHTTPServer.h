#import <Foundation/Foundation.h>
#import "HTTPServer.h"
#import "RoutingConnection.h"

@class RoutingResponder;

@interface RoutingHTTPServer : HTTPServer <RoutingConnectionDelegate>

@property (nonatomic, copy) NSDictionary *defaultHeaders;
@property (nonatomic, copy) NSDictionary *mimeTypes;

- (instancetype)initAtPort:(NSInteger)port;

//Routing
- (void)addResponseHandler:(RoutingResponder *)responder;
- (BOOL)supportsMethod:(NSString *)method;

//Headers
- (void)setDefaultHeader:(NSString *)field
                   value:(NSString *)value;

//MIME types
- (void)setMIMEType:(NSString *)type
       forExtension:(NSString *)ext;
- (NSString *)mimeTypeForPath:(NSString *)path;

@end