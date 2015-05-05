#import <Foundation/Foundation.h>
#import "HTTPConnection.h"

@class RoutingHTTPServer;
@class RoutingResponse;

@interface RoutingConnection : HTTPConnection

@end

@protocol RoutingConnectionDelegate

- (RoutingResponse *)connection:(HTTPConnection *)connection
        didFinishReadingRequest:(HTTPMessage *)request
                       withPath:(NSString *)path
                         method:(NSString *)method
                  andParameters:(NSDictionary *)parameters;

@end