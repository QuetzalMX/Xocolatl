#import "RouteResponse.h"
#import "HTTPConnection.h"
#import "HTTPDataResponse.h"
#import "HTTPFileResponse.h"
#import "HTTPAsyncFileResponse.h"
#import "HTTPResponseProxy.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPRedirectResponse.h"
#import "HTTPRedirectWithPayload.h"

@interface RouteResponse ()

@property (nonatomic, strong) ResponseHandler responseBlock;

@end

@implementation RouteResponse {
	NSMutableDictionary *headers;
	HTTPResponseProxy *proxy;
}

@synthesize connection;
@synthesize headers;

- (id)initWithConnection:(HTTPConnection *)theConnection andResponseBlock:(ResponseHandler)responseBlock;
{
	if (self = [super init]) {
        _responseBlock = responseBlock;
		connection = theConnection;
		headers = [[NSMutableDictionary alloc] init];
		proxy = [[HTTPResponseProxy alloc] init];
	}
	return self;
}

- (NSObject <HTTPResponse>*)response {
	return proxy.response;
}

- (void)setResponse:(NSObject <HTTPResponse>*)response {
    self.responseBlock(response, self.headers);
	proxy.response = response;
}

- (NSObject <HTTPResponse>*)proxiedResponse {
	if (proxy.response != nil || proxy.customStatus != 0 || [headers count] > 0) {
		return proxy;
	}

	return nil;
}

- (NSInteger)statusCode {
	return proxy.status;
}

- (void)setStatusCode:(NSInteger)status {
	proxy.status = status;
}

- (void)setHeader:(NSString *)field value:(NSString *)value {
	[headers setObject:value forKey:field];
}

- (void)respondWithDictionary:(NSDictionary *)dictionary
                      andCode:(NSInteger)code;
{
    NSError *error = nil;
    NSData *jsonDictionary = [NSJSONSerialization dataWithJSONObject:dictionary
                                                             options:0
                                                               error:&error];
    if (error) {
        [self respondWithError:error];
        return;
    }
    
    self.statusCode = code;
    [self respondWithData:jsonDictionary];
}

- (void)respondWithString:(NSString *)string {
	[self respondWithString:string encoding:NSUTF8StringEncoding];
}

- (void)respondWithString:(NSString *)string encoding:(NSStringEncoding)encoding {
	[self respondWithData:[string dataUsingEncoding:encoding]];
}

- (void)respondWithData:(NSData *)data {
	self.response = [[HTTPDataResponse alloc] initWithData:data];
}

- (void)respondWithFile:(NSString *)path {
	[self respondWithFile:path async:NO];
}

- (void)respondWithDynamicFile:(NSString *)path
      andReplacementDictionary:(NSDictionary *)replacementDictionary;
{
    self.response = [[HTTPDynamicFileResponse alloc] initWithFilePath:path
                                                        forConnection:self.connection
                                                            separator:@"%%"
                                                replacementDictionary:replacementDictionary];
}

- (void)respondWithFile:(NSString *)path async:(BOOL)async {
	if (async) {
		self.response = [[HTTPAsyncFileResponse alloc] initWithFilePath:path forConnection:connection];
	} else {
		self.response = [[HTTPFileResponse alloc] initWithFilePath:path forConnection:connection];
	}
}

- (void)respondWithError:(NSError *)error;
{
    self.statusCode = error.code;
    [self respondWithString:error.localizedDescription];
}

- (void)respondWithRedirect:(NSString *)destination;
{
    self.response = [[HTTPRedirectResponse alloc] initWithPath:destination];
}

- (void)respondWithRedirect:(NSString *)destination andData:(NSData *)data;
{
    self.response = [[HTTPRedirectWithPayload alloc] initWithData:data
                                                   andDestination:destination];
}

@end
