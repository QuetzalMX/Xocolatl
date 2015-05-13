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

	// Set the connection header if not already specified
	NSString *connection = [response headerField:@"Connection"];
	if (!connection) {
		connection = [self shouldDie] ? @"close" : @"keep-alive";
		[response setHeaderField:@"Connection" value:connection];
	}
    
    //NOTE: (FO) As per RFC6265:  HTTP State Management Mechanism (http://tools.ietf.org/html/rfc6265#section-3), section 3. Overview, last paragraph:
    // >  Origin servers SHOULD NOT fold multiple Set-Cookie header fields into a single header field.
    // Currently, there is no way to comply with this standard using CFHTTPMessageSetHeaderFieldValue. Using it with the same headerField and multiple values will result in the last value being saved and all others discarded.
    //So we append a number of spaces to Set-Cookie. Browsers will ignore this, so it isn't a big issue at all.
    NSMutableString *setCookieField = [@"Set-Cookie" mutableCopy];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *headerName, id headerValue, BOOL *stop) {
        if ([headerName isEqualToString:setCookieField]) {
            [headerValue enumerateObjectsUsingBlock:^(NSString *aCookie, NSUInteger idx, BOOL *stop) {
                [response setHeaderField:setCookieField
                                   value:aCookie];
                [setCookieField appendString:@" "];
            }];
            
            return;
        }
        
        [response setHeaderField:headerName
                           value:headerValue];
    }];
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
    
    NSLog(@"Connection received: %@ %@", method, path);
    
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

#pragma mark - HTTPS
- (BOOL)isSecureServer;
{
    return YES;
}

- (NSArray *)sslIdentityAndCertificates
{
    static NSArray *sslIdentityAndCertificates;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Read .p12 file
        NSString *path = [[NSBundle mainBundle] pathForResource:@"dev.quetzal.io" ofType:@"p12"];
        NSData *pkcs12data = [[NSData alloc] initWithContentsOfFile:path];
        
        // Import .p12 data
        CFArrayRef keyref = NULL;
        OSStatus sanityCheck;
        sanityCheck = SecPKCS12Import((__bridge CFDataRef)pkcs12data,
                                      (__bridge CFDictionaryRef)@{(__bridge id)kSecImportExportPassphrase: @"alderaan19"},
                                      &keyref);
        
        if (sanityCheck != noErr) {
            NSLog(@"Error while importing pkcs12 [%d]", (int)sanityCheck);
        }
        
        // Identity
        CFDictionaryRef identityDict = CFArrayGetValueAtIndex(keyref, 0);
        SecIdentityRef identityRef = (SecIdentityRef)CFDictionaryGetValue(identityDict,
                                                                          kSecImportItemIdentity);
        
        // Cert
        SecCertificateRef cert = NULL;
        OSStatus status = SecIdentityCopyCertificate(identityRef, &cert);
        if (status)
            NSLog(@"SecIdentityCopyCertificate failed.");
        
        // the certificates array, containing the identity then the root certificate
        sslIdentityAndCertificates = @[(__bridge id)identityRef, (__bridge id)cert];
    });
    
    return sslIdentityAndCertificates;
}

@end