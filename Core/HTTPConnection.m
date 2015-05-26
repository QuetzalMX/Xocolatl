
#import "GCDAsyncSocket.h"
#import "HTTPServer.h"
#import "HTTPConnection+Digest.h"
#import "HTTPMessage.h"
#import "HTTPResponse.h"
#import "HTTPAuthenticationRequest.h"
#import "DDNumber.h"
#import "DDRange.h"
#import "HTTPFileResponse.h"
#import "HTTPAsyncFileResponse.h"
#import "WebSocket.h"
#import "HTTPLogging.h"
#import "HTTPVerbs.h"
#import "HTTPConfig.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

NSString *const HTTPConnectionDidDieNotification = @"HTTPConnectionDidDie";

// The HTTP_RESPONSE and HTTP_FINAL_RESPONSE are designated tags signalling that the response is completely sent.
// That is, in the onSocket:didWriteDataWithTag: method, if the tag is HTTP_RESPONSE or HTTP_FINAL_RESPONSE,
// it is assumed that the response is now completely sent.
// Use HTTP_RESPONSE if it's the end of a response, and you want to start reading more requests afterwards.
// Use HTTP_FINAL_RESPONSE if you wish to terminate the connection after sending the response.
//
// If you are sending multiple data segments in a custom response, make sure that only the last segment has
// the HTTP_RESPONSE tag. For all other segments prior to the last segment use HTTP_PARTIAL_RESPONSE, or some other
// tag of your own invention.
static const NSInteger HTTP_RESPONSE = 90;
static const NSInteger HTTP_FINAL_RESPONSE = 91;

// Define chunk size used to read in data for responses
// This is how much data will be read from disk into RAM at a time
static const NSInteger READ_CHUNKSIZE = 1024 * 512;
static const NSInteger POST_CHUNKSIZE = 1024 * 512;

// Define the various timeouts (in seconds) for various parts of the HTTP process
static const NSInteger TIMEOUT_READ_FIRST_HEADER_LINE       = 30;
static const NSInteger TIMEOUT_READ_SUBSEQUENT_HEADER_LINE  = 30;
static const NSInteger TIMEOUT_READ_BODY                    = -1;
static const NSInteger TIMEOUT_WRITE_HEAD                   = 30;
static const NSInteger TIMEOUT_WRITE_BODY                   = -1;
static const NSInteger TIMEOUT_WRITE_ERROR                  = 30;

// Define the various limits
// MAX_HEADER_LINE_LENGTH: Max length (in bytes) of any single line in a header (including \r\n)
// MAX_HEADER_LINES      : Max number of lines in a single header (including first GET line)
static const NSInteger MAX_HEADER_LINE_LENGTH   = 8190;
static const NSInteger MAX_HEADER_LINES         = 100;

// MAX_CHUNK_LINE_LENGTH : For accepting chunked transfer uploads, max length of chunk size line (including \r\n)
static const NSInteger MAX_CHUNK_LINE_LENGTH = 200;

// Define the various tags we'll use to differentiate what it is we're currently doing.
typedef NS_ENUM(NSUInteger, HTTPRequestTag) {
    HTTPRequestTagHeader = 10,
    HTTPRequestTagBody,//11
    HTTPRequestTagChunkSize,//12
    HTTPRequestTagChunkData,//13
    HTTPRequestTagChunkTrailer,//14
    HTTPRequestTagChunkFooter,//15
    HTTPRequestTagPartialResponseHeader = 21,
    HTTPRequestTagPartialResponseBody,//22
    HTTPRequestTagChunkedResponseHeader = 30,
    HTTPRequestTagChunkedResponseBody,//31
    HTTPRequestTagChunkedResponseFooter,//32
    HTTPRequestTagPartialRangeResponseBody = 40,
    HTTPRequestTagPartialRangesResponseBody = 50,
};

typedef NS_ENUM(NSUInteger, HTTPConnectionTransferType) {
    HTTPConnectionTransferTypeChunked = -1,
};

@interface HTTPConnection ()
{
    dispatch_queue_t connectionQueue;
    
    BOOL started;
    
    unsigned int numHeaderLines;
    
    BOOL sentResponseHeaders;
    
    NSMutableArray *ranges;
    NSMutableArray *ranges_headers;
    NSString *ranges_boundry;
    int rangeIndex;
    
    UInt64 requestContentLength;
    UInt64 requestContentLengthReceived;
    UInt64 requestChunkSize;
    UInt64 requestChunkSizeReceived;
    
    NSMutableArray *responseDataSizes;
}

@property (nonatomic, strong, readwrite) HTTPMessage *request;
@property (nonatomic, strong, readwrite) HTTPConfig *config;
@property (nonatomic, strong) GCDAsyncSocket *asyncSocket;

@end

@implementation HTTPConnection

#pragma mark Init, Dealloc:
/**
 * Associates this new HTTP connection with the given AsyncSocket.
 * This HTTP connection object will become the socket's delegate and take over responsibility for the socket.
**/
- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket
            configuration:(HTTPConfig *)aConfig;
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		
        connectionQueue = aConfig.queue ?: dispatch_queue_create("HTTPConnection", NULL);
		
		// Take over ownership of the socket.
		_asyncSocket = newSocket;
		[_asyncSocket setDelegate:self
                    delegateQueue:connectionQueue];
		
		// Store configuration.
		_config = aConfig;
		
		// Create a new HTTP message.
		_request = [[HTTPMessage alloc] initEmptyRequest];
		
		numHeaderLines = 0;
		
		responseDataSizes = [[NSMutableArray alloc] initWithCapacity:5];
	}
    
	return self;
}

- (void)dealloc
{
	HTTPLogTrace();
	
	[self.asyncSocket setDelegate:nil delegateQueue:NULL];
	[self.asyncSocket disconnect];
	
	if ([self.httpResponse respondsToSelector:@selector(connectionDidClose)]) {
		[self.httpResponse connectionDidClose];
	}
}

#pragma mark - Lifecycle
/**
 * Starting point for the HTTP connection after it has been fully initialized (including subclasses).
 * This method is called by the HTTP server.
**/
- (void)start;
{
	dispatch_async(connectionQueue, ^ {
        if (started) {
            return;
        }
        
        started = YES;
        [self startConnection];
    });
}

/**
 * Starting point for the HTTP connection.
**/
- (void)startConnection
{
	HTTPLogTrace();
    [self.delegate connectionWillStart:self];
    
    //If we get an SSL identity and accompanying trust certificates, we secure the connection.
    //Otherwise, assume we're in good, old HTTP.
    NSArray *certificates = [self.securityDelegate sslIdentityAndCertificates];
    if ([certificates count] > 0)
    {
        // All connections are assumed to be secure.
        // Pass the certificates so we cna begin TLS.
        NSMutableDictionary *settings = [NSMutableDictionary new];
        settings[(NSString *)kCFStreamSSLIsServer] = @YES;
        settings[(NSString *)kCFStreamSSLCertificates] = certificates;
        [self.asyncSocket startTLS:settings];
    }
	
	[self startReadingRequest];
}

/**
 * This method is called by the HTTPServer if it is asked to stop.
 * The server, in turn, invokes stop on each HTTPConnection instance.
 **/
- (void)stop;
{
    dispatch_async(connectionQueue, ^{
        [self.asyncSocket disconnect];
    });
}

#pragma mark - Reading
- (void)startReadingRequest
{
	HTTPLogTrace();
	[self.asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
                         withTimeout:TIMEOUT_READ_FIRST_HEADER_LINE
                           maxLength:MAX_HEADER_LINE_LENGTH
                                 tag:HTTPRequestTagHeader];
}

/** 
 * Parses the query variables in the request URI. 
 * 
 * For example, if the request URI was "/search.html?q=John%20Mayer%20Trio&num=50" 
 * then this method would return the following dictionary: 
 * { 
 *   q = "John Mayer Trio" 
 *   num = "50" 
 * } 
**/ 
- (NSDictionary *)parseGetParams;
{
	if(![self.request isHeaderComplete]) return nil;
	
	NSMutableDictionary *result = nil;
	
	NSURL *url = [self.request url];
	if(url)
	{
		NSString *query = [url query];
		if (query)
		{
            /**
             * Parses the given query string.
             *
             * For example, if the query is "q=John%20Mayer%20Trio&num=50"
             * then this method would return the following dictionary:
             * {
             *   q = "John Mayer Trio" 
             *   num = "50" 
             * }
             **/
            NSArray *components = [query componentsSeparatedByString:@"&"];
            result = [NSMutableDictionary dictionaryWithCapacity:[components count]];
            
            NSUInteger i;
            for (i = 0; i < [components count]; i++)
            {
                NSString *component = [components objectAtIndex:i];
                if ([component length] > 0)
                {
                    NSRange range = [component rangeOfString:@"="];
                    if (range.location != NSNotFound)
                    {
                        NSString *escapedKey = [component substringToIndex:(range.location + 0)];
                        NSString *escapedValue = [component substringFromIndex:(range.location + 1)];
                        
                        if ([escapedKey length] > 0)
                        {
                            CFStringRef k, v;
                            
                            k = CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)escapedKey, CFSTR(""));
                            v = CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)escapedValue, CFSTR(""));
                            
                            NSString *key, *value;
                            
                            key   = (__bridge_transfer NSString *)k;
                            value = (__bridge_transfer NSString *)v;
                            
                            if (key)
                            {
                                if (value)
                                    [result setObject:value forKey:key]; 
                                else 
                                    [result setObject:[NSNull null] forKey:key]; 
                            }
                        }
                    }
                }
            }
		}
	}
	
	return [result copy];
}

/**
 * Attempts to parse the given range header into a series of sequential non-overlapping ranges.
 * If successfull, the variables 'ranges' and 'rangeIndex' will be updated, and YES will be returned.
 * Otherwise, NO is returned, and the range request should be ignored.
 **/
- (BOOL)parseRangeRequest:(NSString *)rangeHeader withContentLength:(UInt64)contentLength
{
	HTTPLogTrace();
	
	// Examples of byte-ranges-specifier values (assuming an entity-body of length 10000):
	// 
	// - The first 500 bytes (byte offsets 0-499, inclusive):  bytes=0-499
	// 
	// - The second 500 bytes (byte offsets 500-999, inclusive): bytes=500-999
	// 
	// - The final 500 bytes (byte offsets 9500-9999, inclusive): bytes=-500
	// 
	// - Or bytes=9500-
	// 
	// - The first and last bytes only (bytes 0 and 9999):  bytes=0-0,-1
	// 
	// - Several legal but not canonical specifications of the second 500 bytes (byte offsets 500-999, inclusive):
	// bytes=500-600,601-999
	// bytes=500-700,601-999
	NSRange eqsignRange = [rangeHeader rangeOfString:@"="];
	
	if(eqsignRange.location == NSNotFound) return NO;
	
	NSUInteger tIndex = eqsignRange.location;
	NSUInteger fIndex = eqsignRange.location + eqsignRange.length;
	
	NSMutableString *rangeType  = [[rangeHeader substringToIndex:tIndex] mutableCopy];
	NSMutableString *rangeValue = [[rangeHeader substringFromIndex:fIndex] mutableCopy];
	
	CFStringTrimWhitespace((__bridge CFMutableStringRef)rangeType);
	CFStringTrimWhitespace((__bridge CFMutableStringRef)rangeValue);
	
	if([rangeType caseInsensitiveCompare:@"bytes"] != NSOrderedSame) return NO;
	
	NSArray *rangeComponents = [rangeValue componentsSeparatedByString:@","];
	
	if([rangeComponents count] == 0) return NO;
	
	ranges = [[NSMutableArray alloc] initWithCapacity:[rangeComponents count]];
	
	rangeIndex = 0;
	
	// Note: We store all range values in the form of DDRange structs, wrapped in NSValue objects.
	// Since DDRange consists of UInt64 values, the range extends up to 16 exabytes.
	
	NSUInteger i;
	for (i = 0; i < [rangeComponents count]; i++)
	{
		NSString *rangeComponent = [rangeComponents objectAtIndex:i];
		
		NSRange dashRange = [rangeComponent rangeOfString:@"-"];
		
		if (dashRange.location == NSNotFound)
		{
			// We're dealing with an individual byte number
			
			UInt64 byteIndex;
			if(![NSNumber parseString:rangeComponent intoUInt64:&byteIndex]) return NO;
			
			if(byteIndex >= contentLength) return NO;
			
			[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(byteIndex, 1)]];
		}
		else
		{
			// We're dealing with a range of bytes
			
			tIndex = dashRange.location;
			fIndex = dashRange.location + dashRange.length;
			
			NSString *r1str = [rangeComponent substringToIndex:tIndex];
			NSString *r2str = [rangeComponent substringFromIndex:fIndex];
			
			UInt64 r1, r2;
			
			BOOL hasR1 = [NSNumber parseString:r1str intoUInt64:&r1];
			BOOL hasR2 = [NSNumber parseString:r2str intoUInt64:&r2];
			
			if (!hasR1)
			{
				// We're dealing with a "-[#]" range
				// 
				// r2 is the number of ending bytes to include in the range
				
				if(!hasR2) return NO;
				if(r2 > contentLength) return NO;
				
				UInt64 startIndex = contentLength - r2;
				
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(startIndex, r2)]];
			}
			else if (!hasR2)
			{
				// We're dealing with a "[#]-" range
				// 
				// r1 is the starting index of the range, which goes all the way to the end
				
				if(r1 >= contentLength) return NO;
				
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(r1, contentLength - r1)]];
			}
			else
			{
				// We're dealing with a normal "[#]-[#]" range
				// 
				// Note: The range is inclusive. So 0-1 has a length of 2 bytes.
				
				if(r1 > r2) return NO;
				if(r2 >= contentLength) return NO;
				
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(r1, r2 - r1 + 1)]];
			}
		}
	}
	
	if([ranges count] == 0) return NO;
	
	// Now make sure none of the ranges overlap
	
	for (i = 0; i < [ranges count] - 1; i++)
	{
		DDRange range1 = [[ranges objectAtIndex:i] ddrangeValue];
		
		NSUInteger j;
		for (j = i+1; j < [ranges count]; j++)
		{
			DDRange range2 = [[ranges objectAtIndex:j] ddrangeValue];
			
			DDRange iRange = DDIntersectionRange(range1, range2);
			
			if(iRange.length != 0)
			{
				return NO;
			}
		}
	}
	
	// Sort the ranges
	
	[ranges sortUsingSelector:@selector(ddrangeCompare:)];
	
	return YES;
}

- (NSString *)requestURI;
{
    return (self.request.url.relativeString) ?: nil;
}

/**
 * This method is called after a full HTTP request has been received.
 * The current request is in the HTTPMessage request variable.
**/
- (void)replyToHTTPRequest
{
	HTTPLogTrace();
	
	if (HTTP_LOG_FLAG_VERBOSE)
	{
		NSString *tempStr = [[NSString alloc] initWithData:self.request.messageData
                                                  encoding:NSUTF8StringEncoding];
		HTTPLogVerbose(@"%@[%p]: Received HTTP request:\n%@", THIS_FILE, self, tempStr);
	}
	
	// Check the HTTP version.
	// We only support version 1.0 and 1.1
	if (![self.request.version isEqualToString:HTTPVersion1_1] &&
        ![self.request.version isEqualToString:HTTPVersion1_0])
	{
        HTTPLogWarn(@"HTTP Server: Error 505 - Version Not Supported: %@ (%@)", self.request.version, [self requestURI]);
        HTTPMessage *response = [self.delegate connection:self
                        responseForUnsupportedHTTPVersion:self.request.version];
        [self writeErrorResponse:response andCloseConnection:NO];
		return;
	}
	
	// Extract requested URI.
	if ([WebSocket isWebSocketRequest:self.request])
	{
		HTTPLogVerbose(@"isWebSocket");
		
        WebSocket *ws = [self.socketDelegate connectionWillTransitionToSocket:self];
		
		if (!ws)
		{
			HTTPMessage *response = [self.delegate connection:self
                                  responseForResourceNotFound:self.request];
            [self writeErrorResponse:response andCloseConnection:NO];
		}
		else
		{
			[ws start];
			
			[self.config.server addWebSocket:ws];
			
			// The WebSocket should now be the delegate of the underlying socket.
			// But gracefully handle the situation if it forgot.
			if (self.asyncSocket.delegate == self)
			{
				HTTPLogWarn(@"%@[%p]: WebSocket forgot to set itself as socket delegate", THIS_FILE, self);
				
				// Disconnect the socket.
				// The socketDidDisconnect delegate method will handle everything else.
				[self.asyncSocket disconnect];
			}
			else
			{
				// The WebSocket is using the socket,
				// so make sure we don't disconnect it in the dealloc method.
				self.asyncSocket = nil;
				
				[self die];
				
				// Note: There is a timing issue here that should be pointed out.
				// 
				// A bug that existed in previous versions happend like so:
				// - We invoked [self die]
				// - This caused us to get released, and our dealloc method to start executing
				// - Meanwhile, AsyncSocket noticed a disconnect, and began to dispatch a socketDidDisconnect at us
				// - The dealloc method finishes execution, and our instance gets freed
				// - The socketDidDisconnect gets run, and a crash occurs
				// 
				// So the issue we want to avoid is releasing ourself when there is a possibility
				// that AsyncSocket might be gearing up to queue a socketDidDisconnect for us.
				// 
				// In this particular situation notice that we invoke [asyncSocket delegate].
				// This method is synchronous concerning AsyncSocket's internal socketQueue.
				// Which means we can be sure, when it returns, that AsyncSocket has already
				// queued any delegate methods for us if it was going to.
				// And if the delegate methods are queued, then we've been properly retained.
				// Meaning we won't get released / dealloc'd until the delegate method has finished executing.
				// 
				// In this rare situation, the die method will get invoked twice.
			}
		}
		
		return;
	}
	
	// Check Authentication (if needed)
	// If not properly authenticated for resource, issue Unauthorized response
    HTTPConnectionSecurityAuthenticationType pathSecurity = [self.securityDelegate connection:self
                                                                             authLevelForPath:self.requestURI];
	if (pathSecurity != HTTPConnectionSecurityAuthenticationTypeNone)
	{
        //The resourse is protected. Can they access this resource?
        if (![self.securityDelegate connection:self
            validateCredentialsForAccessToPath:self.requestURI
                               withAccessLevel:pathSecurity])
        {
            //They cannot.
            HTTPLogInfo(@"HTTP Server: Error 401 - Unauthorized (%@)", [self requestURI]);
            HTTPMessage *response = [self.securityDelegate connection:self
                                          failedToAuthenticateForPath:self.requestURI
                                                      withAccessLevel:pathSecurity];
            
            if (pathSecurity == HTTPConnectionSecurityAuthenticationTypeBasic ||
                pathSecurity == HTTPConnectionSecurityAuthenticationTypeDigest)
            {
                //Issue a challenge if we're using Basic or Digest.
                NSString *authInfo;
                if (pathSecurity == HTTPConnectionSecurityAuthenticationTypeDigest)
                {
                    NSString *authFormat = @"Digest realm=\"%@\", qop=\"auth\", nonce=\"%@\"";
                    authInfo = [NSString stringWithFormat:authFormat, [self.securityDelegate authenticationRealmForConnection:self], [[self class] generateNonce]];
                }
                else if (pathSecurity == HTTPConnectionSecurityAuthenticationTypeBasic)
                {
                    NSString *authFormat = @"Basic realm=\"%@\"";
                    authInfo = [NSString stringWithFormat:authFormat, [self.securityDelegate authenticationRealmForConnection:self]];
                }
                
                [response setHeaderField:@"WWW-Authenticate" value:authInfo];
            }
            
            [self writeErrorResponse:response
                  andCloseConnection:NO];
            return;
        }
	}
	
	//By now, the method is supported and, if auth is required, the user is already authenticated.
    //So now, all we have to do is respond.
	self.httpResponse = [self.routingDelegate responseForConnection:self];
	if (!self.httpResponse)
    {
		[self.delegate connection:self
      responseForResourceNotFound:self.request];
		return;
	}
	
	[self sendResponseHeadersAndBody];
}

/**
 * Prepares a single-range response.
 * 
 * Note: The returned HTTPMessage is owned by the sender, who is responsible for releasing it.
**/
- (HTTPMessage *)newUniRangeResponse:(UInt64)contentLength
{
	HTTPLogTrace();
	
	// Status Code 206 - Partial Content
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:206 description:nil version:HTTPVersion1_1];
	
	DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
	
	NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", range.length];
	[response setHeaderField:@"Content-Length" value:contentLengthStr];
	
	NSString *rangeStr = [NSString stringWithFormat:@"%qu-%qu", range.location, DDMaxRange(range) - 1];
	NSString *contentRangeStr = [NSString stringWithFormat:@"bytes %@/%qu", rangeStr, contentLength];
	[response setHeaderField:@"Content-Range" value:contentRangeStr];
	
	return response;
}

/**
 * Prepares a multi-range response.
 * 
 * Note: The returned HTTPMessage is owned by the sender, who is responsible for releasing it.
**/
- (HTTPMessage *)newMultiRangeResponse:(UInt64)contentLength
{
	HTTPLogTrace();
	
	// Status Code 206 - Partial Content
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:206 description:nil version:HTTPVersion1_1];
	
	// We have to send each range using multipart/byteranges
	// So each byterange has to be prefix'd and suffix'd with the boundry
	// Example:
	// 
	// HTTP/1.1 206 Partial Content
	// Content-Length: 220
	// Content-Type: multipart/byteranges; boundary=4554d24e986f76dd6
	// 
	// 
	// --4554d24e986f76dd6
	// Content-Range: bytes 0-25/4025
	// 
	// [...]
	// --4554d24e986f76dd6
	// Content-Range: bytes 3975-4024/4025
	// 
	// [...]
	// --4554d24e986f76dd6--
	
	ranges_headers = [[NSMutableArray alloc] initWithCapacity:[ranges count]];
	
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	ranges_boundry = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	
	NSString *startingBoundryStr = [NSString stringWithFormat:@"\r\n--%@\r\n", ranges_boundry];
	NSString *endingBoundryStr = [NSString stringWithFormat:@"\r\n--%@--\r\n", ranges_boundry];
	
	UInt64 actualContentLength = 0;
	
	NSUInteger i;
	for (i = 0; i < [ranges count]; i++)
	{
		DDRange range = [[ranges objectAtIndex:i] ddrangeValue];
		
		NSString *rangeStr = [NSString stringWithFormat:@"%qu-%qu", range.location, DDMaxRange(range) - 1];
		NSString *contentRangeVal = [NSString stringWithFormat:@"bytes %@/%qu", rangeStr, contentLength];
		NSString *contentRangeStr = [NSString stringWithFormat:@"Content-Range: %@\r\n\r\n", contentRangeVal];
		
		NSString *fullHeader = [startingBoundryStr stringByAppendingString:contentRangeStr];
		NSData *fullHeaderData = [fullHeader dataUsingEncoding:NSUTF8StringEncoding];
		
		[ranges_headers addObject:fullHeaderData];
		
		actualContentLength += [fullHeaderData length];
		actualContentLength += range.length;
	}
	
	NSData *endingBoundryData = [endingBoundryStr dataUsingEncoding:NSUTF8StringEncoding];
	
	actualContentLength += [endingBoundryData length];
	
	NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", actualContentLength];
	[response setHeaderField:@"Content-Length" value:contentLengthStr];
	
	NSString *contentTypeStr = [NSString stringWithFormat:@"multipart/byteranges; boundary=%@", ranges_boundry];
	[response setHeaderField:@"Content-Type" value:contentTypeStr];
	
	return response;
}

/**
 * Returns the chunk size line that must precede each chunk of data when using chunked transfer encoding.
 * This consists of the size of the data, in hexadecimal, followed by a CRLF.
**/
- (NSData *)chunkedTransferSizeLineForLength:(NSUInteger)length
{
	return [[NSString stringWithFormat:@"%lx\r\n", (unsigned long)length] dataUsingEncoding:NSUTF8StringEncoding];
}

/**
 * Returns the data that signals the end of a chunked transfer.
**/
- (NSData *)chunkedTransferFooter
{
	// Each data chunk is preceded by a size line (in hex and including a CRLF),
	// followed by the data itself, followed by another CRLF.
	// After every data chunk has been sent, a zero size line is sent,
	// followed by optional footer (which are just more headers),
	// and followed by a CRLF on a line by itself.
	
	return [@"\r\n0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)sendResponseHeadersAndBody
{
	if ([self.httpResponse respondsToSelector:@selector(delayResponseHeaders)]) {
		if ([self.httpResponse delayResponseHeaders]) {
			return;
		}
	}
	
	BOOL isChunked = NO;
	if ([self.httpResponse respondsToSelector:@selector(isChunked)]) {
		isChunked = [self.httpResponse isChunked];
	}
	
	// If a response is "chunked", this simply means the HTTPResponse object
	// doesn't know the content-length in advance.
	UInt64 contentLength = 0;
	if (!isChunked) {
		contentLength = [self.httpResponse contentLength];
	}
	
	// Check for specific range request
	NSString *rangeHeader = [self.request headerField:@"Range"];
	
	// If the response is "chunked" then we don't know the exact content-length.
	// This means we'll be unable to process any range requests.
	// This is because range requests might include a range like "give me the last 100 bytes"
    BOOL isRangeRequest = NO;
	if (!isChunked && rangeHeader) {
		if ([self parseRangeRequest:rangeHeader withContentLength:contentLength]) {
			isRangeRequest = YES;
		}
	}
	
	HTTPMessage *response;
	if (!isRangeRequest) {
		// Create response
		// Default status code: 200 - OK
		NSInteger status = 200;
		
		if ([self.httpResponse respondsToSelector:@selector(status)])
		{
			status = [self.httpResponse status];
		}
		response = [[HTTPMessage alloc] initResponseWithStatusCode:status description:nil version:HTTPVersion1_1];
		
		if (isChunked)
		{
			[response setHeaderField:@"Transfer-Encoding" value:@"chunked"];
		}
		else
		{
			NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", contentLength];
			[response setHeaderField:@"Content-Length" value:contentLengthStr];
		}
	}
	else
	{
		if ([ranges count] == 1)
		{
			response = [self newUniRangeResponse:contentLength];
		}
		else
		{
			response = [self newMultiRangeResponse:contentLength];
		}
	}
	
	BOOL isZeroLengthResponse = !isChunked && (contentLength == 0);
    
	// If they issue a 'HEAD' command, we don't have to include the file
	// If they issue a 'GET' command, we need to include the file
	if ([[self.request method] isEqualToString:@"HEAD"] || isZeroLengthResponse)
	{
		NSData *responseData = [self preprocessResponse:response];
		[self.asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
		
		sentResponseHeaders = YES;
	}
	else
	{
		// Write the header response
		NSData *responseData = [self preprocessResponse:response];
		[self.asyncSocket writeData:responseData
                        withTimeout:TIMEOUT_WRITE_HEAD
                                tag:HTTPRequestTagPartialResponseHeader];
		
		sentResponseHeaders = YES;
		
		// Now we need to send the body of the response
		if (!isRangeRequest)
		{
			// Regular request
			NSData *data = [self.httpResponse readDataOfLength:READ_CHUNKSIZE];
			
			if ([data length] > 0)
			{
				[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
				
				if (isChunked)
				{
					NSData *chunkSize = [self chunkedTransferSizeLineForLength:[data length]];
					[self.asyncSocket writeData:chunkSize
                                    withTimeout:TIMEOUT_WRITE_HEAD
                                            tag:HTTPRequestTagChunkedResponseHeader];
					
					[self.asyncSocket writeData:data
                                    withTimeout:TIMEOUT_WRITE_BODY
                                            tag:HTTPRequestTagChunkedResponseBody];
					
					if ([self.httpResponse isDone])
					{
						NSData *footer = [self chunkedTransferFooter];
						[self.asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
					}
					else
					{
						NSData *footer = [GCDAsyncSocket CRLFData];
						[self.asyncSocket writeData:footer
                                        withTimeout:TIMEOUT_WRITE_HEAD
                                                tag:HTTPRequestTagChunkedResponseFooter];
					}
				}
				else
				{
					long tag = [self.httpResponse isDone] ? HTTP_RESPONSE : HTTPRequestTagPartialResponseBody;
					[self.asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
				}
			}
		}
		else
		{
			// Client specified a byte range in request
			
			if ([ranges count] == 1)
			{
				// Client is requesting a single range
				DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
				
				[self.httpResponse setOffset:range.location];
				
				NSUInteger bytesToRead = range.length < READ_CHUNKSIZE ? (NSUInteger)range.length : READ_CHUNKSIZE;
				
				NSData *data = [self.httpResponse readDataOfLength:bytesToRead];
				
				if ([data length] > 0)
				{
					[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
					
					long tag = [data length] == range.length ? HTTP_RESPONSE : HTTPRequestTagPartialRangeResponseBody;
					[self.asyncSocket writeData:data
                                    withTimeout:TIMEOUT_WRITE_BODY
                                            tag:tag];
				}
			}
			else
			{
				// Client is requesting multiple ranges
				// We have to send each range using multipart/byteranges
				
				// Write range header
				NSData *rangeHeaderData = [ranges_headers objectAtIndex:0];
				[self.asyncSocket writeData:rangeHeaderData
                                withTimeout:TIMEOUT_WRITE_HEAD
                                        tag:HTTPRequestTagPartialResponseHeader];
				
				// Start writing range body
				DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
				
				[self.httpResponse setOffset:range.location];
				
				NSUInteger bytesToRead = range.length < READ_CHUNKSIZE ? (NSUInteger)range.length : READ_CHUNKSIZE;
				
				NSData *data = [self.httpResponse readDataOfLength:bytesToRead];
				
				if ([data length] > 0)
				{
					[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
					
					[self.asyncSocket writeData:data
                                    withTimeout:TIMEOUT_WRITE_BODY
                                            tag:HTTPRequestTagPartialRangesResponseBody];
				}
			}
		}
	}
	
}

/**
 * Returns the number of bytes of the http response body that are sitting in asyncSocket's write queue.
 * 
 * We keep track of this information in order to keep our memory footprint low while
 * working with asynchronous HTTPResponse objects.
**/
- (NSUInteger)writeQueueSize
{
	NSUInteger result = 0;
	
	NSUInteger i;
	for(i = 0; i < [responseDataSizes count]; i++)
	{
		result += [[responseDataSizes objectAtIndex:i] unsignedIntegerValue];
	}
	
	return result;
}

/**
 * Sends more data, if needed, without growing the write queue over its approximate size limit.
 * The last chunk of the response body will be sent with a tag of HTTP_RESPONSE.
 * 
 * This method should only be called for standard (non-range) responses.
**/
- (void)continueSendingStandardResponseBody
{
	HTTPLogTrace();
	
	// This method is called when either asyncSocket has finished writing one of the response data chunks,
	// or when an asynchronous HTTPResponse object informs us that it has more available data for us to send.
	// In the case of the asynchronous HTTPResponse, we don't want to blindly grab the new data,
	// and shove it onto asyncSocket's write queue.
	// Doing so could negatively affect the memory footprint of the application.
	// Instead, we always ensure that we place no more than READ_CHUNKSIZE bytes onto the write queue.
	// 
	// Note that this does not affect the rate at which the HTTPResponse object may generate data.
	// The HTTPResponse is free to do as it pleases, and this is up to the application's developer.
	// If the memory footprint is a concern, the developer creating the custom HTTPResponse object may freely
	// use the calls to readDataOfLength as an indication to start generating more data.
	// This provides an easy way for the HTTPResponse object to throttle its data allocation in step with the rate
	// at which the socket is able to send it.
	
	NSUInteger writeQueueSize = [self writeQueueSize];
	
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	
	NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
	NSData *data = [self.httpResponse readDataOfLength:available];
	
	if ([data length] > 0)
	{
		[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
		
		BOOL isChunked = NO;
		
		if ([self.httpResponse respondsToSelector:@selector(isChunked)])
		{
			isChunked = [self.httpResponse isChunked];
		}
		
		if (isChunked)
		{
			NSData *chunkSize = [self chunkedTransferSizeLineForLength:[data length]];
			[self.asyncSocket writeData:chunkSize
                            withTimeout:TIMEOUT_WRITE_HEAD
                                    tag:HTTPRequestTagChunkedResponseHeader];
			
			[self.asyncSocket writeData:data
                            withTimeout:TIMEOUT_WRITE_BODY
                                    tag:HTTPRequestTagChunkedResponseBody];
			
			if([self.httpResponse isDone])
			{
				NSData *footer = [self chunkedTransferFooter];
				[self.asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
			}
			else
			{
				NSData *footer = [GCDAsyncSocket CRLFData];
				[self.asyncSocket writeData:footer
                                withTimeout:TIMEOUT_WRITE_HEAD
                                        tag:HTTPRequestTagChunkedResponseFooter];
			}
		}
		else
		{
			long tag = [self.httpResponse isDone] ? HTTP_RESPONSE : HTTPRequestTagPartialResponseBody;
			[self.asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
		}
	}
}

/**
 * Sends more data, if needed, without growing the write queue over its approximate size limit.
 * The last chunk of the response body will be sent with a tag of HTTP_RESPONSE.
 * 
 * This method should only be called for single-range responses.
**/
- (void)continueSendingSingleRangeResponseBody
{
	HTTPLogTrace();
	
	// This method is called when either asyncSocket has finished writing one of the response data chunks,
	// or when an asynchronous response informs us that is has more available data for us to send.
	// In the case of the asynchronous response, we don't want to blindly grab the new data,
	// and shove it onto asyncSocket's write queue.
	// Doing so could negatively affect the memory footprint of the application.
	// Instead, we always ensure that we place no more than READ_CHUNKSIZE bytes onto the write queue.
	// 
	// Note that this does not affect the rate at which the HTTPResponse object may generate data.
	// The HTTPResponse is free to do as it pleases, and this is up to the application's developer.
	// If the memory footprint is a concern, the developer creating the custom HTTPResponse object may freely
	// use the calls to readDataOfLength as an indication to start generating more data.
	// This provides an easy way for the HTTPResponse object to throttle its data allocation in step with the rate
	// at which the socket is able to send it.
	
	NSUInteger writeQueueSize = [self writeQueueSize];
	
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	
	DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
	
	UInt64 offset = [self.httpResponse offset];
	UInt64 bytesRead = offset - range.location;
	UInt64 bytesLeft = range.length - bytesRead;
	
	if (bytesLeft > 0)
	{
		NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
		NSUInteger bytesToRead = bytesLeft < available ? (NSUInteger)bytesLeft : available;
		
		NSData *data = [self.httpResponse readDataOfLength:bytesToRead];
		
		if ([data length] > 0)
		{
			[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
			
			long tag = [data length] == bytesLeft ? HTTP_RESPONSE : HTTPRequestTagPartialRangeResponseBody;
			[self.asyncSocket writeData:data
                            withTimeout:TIMEOUT_WRITE_BODY
                                    tag:tag];
		}
	}
}

/**
 * Sends more data, if needed, without growing the write queue over its approximate size limit.
 * The last chunk of the response body will be sent with a tag of HTTP_RESPONSE.
 * 
 * This method should only be called for multi-range responses.
**/
- (void)continueSendingMultiRangeResponseBody
{
	HTTPLogTrace();
	
	// This method is called when either asyncSocket has finished writing one of the response data chunks,
	// or when an asynchronous HTTPResponse object informs us that is has more available data for us to send.
	// In the case of the asynchronous HTTPResponse, we don't want to blindly grab the new data,
	// and shove it onto asyncSocket's write queue.
	// Doing so could negatively affect the memory footprint of the application.
	// Instead, we always ensure that we place no more than READ_CHUNKSIZE bytes onto the write queue.
	// 
	// Note that this does not affect the rate at which the HTTPResponse object may generate data.
	// The HTTPResponse is free to do as it pleases, and this is up to the application's developer.
	// If the memory footprint is a concern, the developer creating the custom HTTPResponse object may freely
	// use the calls to readDataOfLength as an indication to start generating more data.
	// This provides an easy way for the HTTPResponse object to throttle its data allocation in step with the rate
	// at which the socket is able to send it.
	
	NSUInteger writeQueueSize = [self writeQueueSize];
	
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	
	DDRange range = [[ranges objectAtIndex:rangeIndex] ddrangeValue];
	
	UInt64 offset = [self.httpResponse offset];
	UInt64 bytesRead = offset - range.location;
	UInt64 bytesLeft = range.length - bytesRead;
	
	if (bytesLeft > 0)
	{
		NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
		NSUInteger bytesToRead = bytesLeft < available ? (NSUInteger)bytesLeft : available;
		
		NSData *data = [self.httpResponse readDataOfLength:bytesToRead];
		
		if ([data length] > 0)
		{
			[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
			
			[self.asyncSocket writeData:data
                            withTimeout:TIMEOUT_WRITE_BODY
                                    tag:HTTPRequestTagPartialRangesResponseBody];
		}
	}
	else
	{
		if (++rangeIndex < [ranges count])
		{
			// Write range header
			NSData *rangeHeader = [ranges_headers objectAtIndex:rangeIndex];
			[self.asyncSocket writeData:rangeHeader
                            withTimeout:TIMEOUT_WRITE_HEAD
                                    tag:HTTPRequestTagPartialResponseHeader];
			
			// Start writing range body
			range = [[ranges objectAtIndex:rangeIndex] ddrangeValue];
			
			[self.httpResponse setOffset:range.location];
			
			NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
			NSUInteger bytesToRead = range.length < available ? (NSUInteger)range.length : available;
			
			NSData *data = [self.httpResponse readDataOfLength:bytesToRead];
			
			if ([data length] > 0)
			{
				[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
				
				[self.asyncSocket writeData:data
                                withTimeout:TIMEOUT_WRITE_BODY
                                        tag:HTTPRequestTagPartialRangesResponseBody];
			}
		}
		else
		{
			// We're not done yet - we still have to send the closing boundry tag
			NSString *endingBoundryStr = [NSString stringWithFormat:@"\r\n--%@--\r\n", ranges_boundry];
			NSData *endingBoundryData = [endingBoundryStr dataUsingEncoding:NSUTF8StringEncoding];
			
			[self.asyncSocket writeData:endingBoundryData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Responses
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark Uploads
- (void)processBodyData:(NSData *)postDataChunk
{
    if ([self.delegate connection:self shouldAppendData:postDataChunk])
    {
        BOOL result = [self.request appendData:postDataChunk];
        if (!result) {
            NSLog(@"Could not add data to connection");
        }
    }
}

#pragma mark Errors
- (void)writeErrorResponse:(HTTPMessage *)errorResponse
        andCloseConnection:(BOOL)closeConnection;
{
    NSAssert(errorResponse != nil, @"A response is expected when receiving invalid header data");
    [self.delegate connection:self
        willSendErrorResponse:errorResponse];
    
    NSUInteger tag = (closeConnection) ? HTTP_FINAL_RESPONSE : HTTP_RESPONSE;
    [self.asyncSocket writeData:errorResponse.messageData withTimeout:TIMEOUT_WRITE_ERROR tag:tag];
    // Note: We use the HTTP_FINAL_RESPONSE tag to disconnect after the response is sent
    // 400 - In an invalid request, we won't be able to recover and move on to another request afterwards since we don't know where this request ends and where the next one begins.
    // 405 - the method may include an http body. Since we can't be sure, we should close the connection.
}

- (void)handleInvalidRequest:(NSData *)data;
{
    HTTPLogWarn(@"%@[%p]: Malformed request", THIS_FILE, self);
    HTTPMessage *response = [self.delegate connection:self
                          responseForMalformedRequest:data];

    [self writeErrorResponse:response andCloseConnection:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Headers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called immediately prior to sending the response headers.
 * This method adds standard header fields, and then converts the response to an NSData object.
**/
- (NSData *)preprocessResponse:(HTTPMessage *)response
{
	HTTPLogTrace();
	[self.routingDelegate connection:self
                    willRespondUsing:response];
    
	return [response messageData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark GCDAsyncSocket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called after the socket has successfully read data from the stream.
 * Remember that this method will only be called after the socket reaches a CRLF, or after it's read the proper length.
**/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
    //Did we just read a header?
	if (tag == HTTPRequestTagHeader)
	{
		// We did. Append the header line to the http message.
		if (![self.request appendData:data])
		{
            //We couldn't append the data. Bail.
            HTTPLogWarn(@"%@[%p]: Malformed request", THIS_FILE, self);
            [self handleInvalidRequest:data];
            return;
		}
        
        //We could append the data. Are the headers complete?
        if (![self.request isHeaderComplete])
		{
			//They are incomplete. We haven't yet received a CRLF on a line by itself, indicating the end of the header.
			if (++numHeaderLines > MAX_HEADER_LINES)
			{
				// Reached the maximum amount of header lines in a single HTTP request.
				// This could be an attempted DOS attack.
                [self.asyncSocket disconnect];
				return;
			}

            //There's still some more lines to read.
            [self.asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
                                 withTimeout:TIMEOUT_READ_SUBSEQUENT_HEADER_LINE
                                   maxLength:MAX_HEADER_LINE_LENGTH
                                         tag:HTTPRequestTagHeader];
            return;
		}

        // We have an entire HTTP request header from the client.
        NSString *method = [self.request method];
        NSString *uri = [self requestURI];
        NSString *transferEncoding = [self.request headerField:@"Transfer-Encoding"];
        NSString *contentLength = [self.request headerField:@"Content-Length"];
        
        // Content-Length MUST be present for upload methods (such as POST or PUT) and MUST NOT be present for other methods.
        BOOL expectsUpload = [self.routingDelegate connection:self
                                 expectsRequestBodyFromMethod:method
                                                       atPath:uri];
        if (expectsUpload)
        {
#warning Double-check this if/else before merging.
            //We're in PUT/POST/PATCH territory. Is this chunked or not?
            BOOL transferEncodingChunked = transferEncoding && ![transferEncoding caseInsensitiveCompare:@"Chunked"];
            if (!transferEncodingChunked)
            {
                //Not chunked. Verify the contentLength.
                if (!contentLength)
                {
                    //No contentLength. We can't proceed.
                    HTTPLogWarn(@"%@[%p]: Method expects request body, but had no specified Content-Length",
                                THIS_FILE, self);
                    
                    [self handleInvalidRequest:nil];
                    return;
                }
                
                //Content length is there. Is it a valid number?
                if (![NSNumber parseString:(NSString *)contentLength intoUInt64:&requestContentLength])
                {
                    //Nope. Invalid number.
                    HTTPLogWarn(@"%@[%p]: Unable to parse Content-Length header into a valid number",
                                THIS_FILE, self);
                    
                    [self handleInvalidRequest:nil];
                    return;
                }
            } else {
                //Chunked.
                requestContentLength = HTTPConnectionTransferTypeChunked;
            }
        }
        else
        {
            //We're in HEAD/GET territory. We shouldn't have a contentLength.
            if (contentLength)
            {
                // Received Content-Length header for method not expecting an upload.
                // This better be zero...
                if (![NSNumber parseString:(NSString *)contentLength intoUInt64:&requestContentLength])
                {
                    //It's an invalid number. We can't proceed.
                    HTTPLogWarn(@"%@[%p]: Unable to parse Content-Length header into a valid number",
                                THIS_FILE, self);
                    
                    [self handleInvalidRequest:nil];
                    return;
                }
                
                if (requestContentLength > 0)
                {
                    //Content-length is not 0. We're not expecting this.
                    HTTPLogWarn(@"%@[%p]: Method not expecting request body had non-zero Content-Length",
                                THIS_FILE, self);
                    
                    [self handleInvalidRequest:nil];
                    return;
                }
            }
            
            requestContentLength = 0;
            requestContentLengthReceived = 0;
        }
        
        // Check to make sure the given method is supported.
        if (![self.routingDelegate connection:self
                               supportsMethod:method
                                       atPath:uri])
        {
            // The method is not supported.
            HTTPLogWarn(@"HTTP Server: Error 405 - Method Not Allowed: %@ (%@)", method, [self requestURI]);
            HTTPMessage *response = [self.routingDelegate connection:self
                                            responseForUnknownMethod:method
                                                              atPath:uri];
            [self writeErrorResponse:response andCloseConnection:YES];
            return;
        }
        
        if (expectsUpload)
        {
            // Reset the total amount of data received for the upload
            requestContentLengthReceived = 0;
            
            // Prepare for the upload
            [self.delegate connection:self
                   willReadBodyOfSize:requestContentLength];
            
            if (requestContentLength > 0)
            {
                // Start reading the request body
                if (requestContentLength == HTTPConnectionTransferTypeChunked)
                {
                    [self.asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
                                         withTimeout:TIMEOUT_READ_BODY
                                           maxLength:MAX_CHUNK_LINE_LENGTH
                                                 tag:HTTPRequestTagChunkSize];
                }
                else
                {
                    NSUInteger bytesToRead;
                    if (requestContentLength < POST_CHUNKSIZE)
                        bytesToRead = (NSUInteger)requestContentLength;
                    else
                        bytesToRead = POST_CHUNKSIZE;
                    
                    [self.asyncSocket readDataToLength:bytesToRead
                                           withTimeout:TIMEOUT_READ_BODY
                                                   tag:HTTPRequestTagBody];
                }
            }
            else
            {
                // Empty upload
                [self.delegate connection:self
                        didReadBodyOfSize:requestContentLength];
                [self replyToHTTPRequest];
            }
        }
        else
        {
            // Now we need to reply to the request
            [self replyToHTTPRequest];
        }
	}
	else
	{
		BOOL doneReadingRequest = NO;
		
		// A chunked message body contains a series of chunks,
		// followed by a line with "0" (zero),
		// followed by optional footers (just like headers),
		// and a blank line.
		// 
		// Each chunk consists of two parts:
		// 
		// 1. A line with the size of the chunk data, in hex,
		//    possibly followed by a semicolon and extra parameters you can ignore (none are currently standard),
		//    and ending with CRLF.
		// 2. The data itself, followed by CRLF.
		// 
		// Part 1 is represented by HTTP_REQUEST_CHUNK_SIZE
		// Part 2 is represented by HTTP_REQUEST_CHUNK_DATA and HTTP_REQUEST_CHUNK_TRAILER
		// where the trailer is the CRLF that follows the data.
		// 
		// The optional footers and blank line are represented by HTTP_REQUEST_CHUNK_FOOTER.
		
		if (tag == HTTPRequestTagChunkSize)
		{
			// We have just read in a line with the size of the chunk data, in hex, 
			// possibly followed by a semicolon and extra parameters that can be ignored,
			// and ending with CRLF.
			
			NSString *sizeLine = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			
			errno = 0;  // Reset errno before calling strtoull() to ensure it is always zero on success
			requestChunkSize = (UInt64)strtoull([sizeLine UTF8String], NULL, 16);
			requestChunkSizeReceived = 0;
			
			if (errno != 0)
			{
				HTTPLogWarn(@"%@[%p]: Method expects chunk size, but received something else", THIS_FILE, self);
				
				[self handleInvalidRequest:nil];
				return;
			}
			
			if (requestChunkSize > 0)
			{
				NSUInteger bytesToRead;
				bytesToRead = (requestChunkSize < POST_CHUNKSIZE) ? (NSUInteger)requestChunkSize : POST_CHUNKSIZE;
				
				[self.asyncSocket readDataToLength:bytesToRead
                                       withTimeout:TIMEOUT_READ_BODY
                                               tag:HTTPRequestTagChunkData];
			}
			else
			{
				// This is the "0" (zero) line,
				// which is to be followed by optional footers (just like headers) and finally a blank line.
				
				[self.asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
                                     withTimeout:TIMEOUT_READ_BODY
                                       maxLength:MAX_HEADER_LINE_LENGTH
                                             tag:HTTPRequestTagChunkFooter];
			}
			
			return;
		}
		else if (tag == HTTPRequestTagChunkData)
		{
			// We just read part of the actual data.
			requestContentLengthReceived += [data length];
			requestChunkSizeReceived += [data length];
			[self processBodyData:data];
			
            //How much of it is remaining?
			UInt64 bytesLeft = requestChunkSize - requestChunkSizeReceived;
			if (bytesLeft > 0)
			{
                //Some. Keep reading.
				NSUInteger bytesToRead = (bytesLeft < POST_CHUNKSIZE) ? (NSUInteger)bytesLeft : POST_CHUNKSIZE;
				
				[self.asyncSocket readDataToLength:bytesToRead
                                       withTimeout:TIMEOUT_READ_BODY
                                               tag:HTTPRequestTagChunkData];
			}
			else
			{
				// None. We've read in all the data for this chunk.
				// The data is followed by a CRLF, which we need to read (and basically ignore)
				[self.asyncSocket readDataToLength:2
                                       withTimeout:TIMEOUT_READ_BODY
                                               tag:HTTPRequestTagChunkTrailer];
			}
			
			return;
		}
		else if (tag == HTTPRequestTagChunkTrailer)
		{
			// This should be the CRLF following the data.
			// Just ensure it's a CRLF.
			if (![data isEqualToData:[GCDAsyncSocket CRLFData]])
			{
				HTTPLogWarn(@"%@[%p]: Method expects chunk trailer, but is missing", THIS_FILE, self);
				[self handleInvalidRequest:nil];
				return;
			}
			
			// Now continue with the next chunk
			[self.asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
                                 withTimeout:TIMEOUT_READ_BODY
                                   maxLength:MAX_CHUNK_LINE_LENGTH
                                         tag:HTTPRequestTagChunkSize];
			
		}
		else if (tag == HTTPRequestTagChunkFooter)
		{
			if (++numHeaderLines > MAX_HEADER_LINES)
			{
				// Reached the maximum amount of header lines in a single HTTP request
				// This could be an attempted DOS attack
				[self.asyncSocket disconnect];
				
				// Explictly return to ensure we don't do anything after the socket disconnect
				return;
			}
			
			if ([data length] > 2)
			{
				// We read in a footer.
				// In the future we may want to append these to the request.
				// For now we ignore, and continue reading the footers, waiting for the final blank line.
				[self.asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
                                     withTimeout:TIMEOUT_READ_BODY
                                       maxLength:MAX_HEADER_LINE_LENGTH
                                             tag:HTTPRequestTagChunkFooter];
			}
			else
			{
				doneReadingRequest = YES;
			}
		}
		else  // HTTP_REQUEST_BODY
		{
			// Handle a chunk of data from the POST body
			requestContentLengthReceived += [data length];
			[self processBodyData:data];
			
			if (requestContentLengthReceived < requestContentLength)
			{
				// We're not done reading the post body yet...
				UInt64 bytesLeft = requestContentLength - requestContentLengthReceived;
				NSUInteger bytesToRead = bytesLeft < POST_CHUNKSIZE ? (NSUInteger)bytesLeft : POST_CHUNKSIZE;
				
				[self.asyncSocket readDataToLength:bytesToRead
                                       withTimeout:TIMEOUT_READ_BODY
                                               tag:HTTPRequestTagBody];
			}
			else
			{
				doneReadingRequest = YES;
			}
		}
		
		// Now that the entire body has been received, we need to reply to the request
		if (doneReadingRequest)
		{
			[self.delegate connection:self
                    didReadBodyOfSize:requestContentLength];
			[self replyToHTTPRequest];
		}
	}
}

/**
 * This method is called after the socket has successfully written data to the stream.
**/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	BOOL doneSendingResponse = NO;
	
	if (tag == HTTPRequestTagPartialResponseBody)
	{
		// Update the amount of data we have in asyncSocket's write queue
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
		
		// We only wrote a part of the response - there may be more
		[self continueSendingStandardResponseBody];
	}
	else if (tag == HTTPRequestTagChunkedResponseBody)
	{
		// Update the amount of data we have in asyncSocket's write queue.
		// This will allow asynchronous responses to continue sending more data.
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
		// Don't continue sending the response yet.
		// The chunked footer that was sent after the body will tell us if we have more data to send.
	}
	else if (tag == HTTPRequestTagChunkedResponseFooter)
	{
		// Normal chunked footer indicating we have more data to send (non final footer).
		[self continueSendingStandardResponseBody];
	}
	else if (tag == HTTPRequestTagPartialRangeResponseBody)
	{
		// Update the amount of data we have in asyncSocket's write queue
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
		// We only wrote a part of the range - there may be more
		[self continueSendingSingleRangeResponseBody];
	}
	else if (tag == HTTPRequestTagPartialRangesResponseBody)
	{
		// Update the amount of data we have in asyncSocket's write queue
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
		// We only wrote part of the range - there may be more, or there may be more ranges
		[self continueSendingMultiRangeResponseBody];
	}
	else if (tag == HTTP_RESPONSE || tag == HTTP_FINAL_RESPONSE)
	{
		// Update the amount of data we have in asyncSocket's write queue
		if ([responseDataSizes count] > 0)
		{
			[responseDataSizes removeObjectAtIndex:0];
		}
		
		doneSendingResponse = YES;
	}
	
	if (doneSendingResponse)
	{
		// Inform the http response that we're done
		if ([self.httpResponse respondsToSelector:@selector(connectionDidClose)])
		{
			[self.httpResponse connectionDidClose];
		}
		
		if (tag == HTTP_FINAL_RESPONSE)
		{
			// Cleanup after the last request
			[self finishResponse];
			
			// Terminate the connection
			[self.asyncSocket disconnect];
			
			// Explictly return to ensure we don't do anything after the socket disconnects
			return;
		}
		else
		{
			if ([self shouldDie])
			{
				// Cleanup after the last request
				// Note: Don't do this before calling shouldDie, as it needs the request object still.
				[self finishResponse];
				
				// The only time we should invoke [self die] is from socketDidDisconnect,
				// or if the socket gets taken over by someone else like a WebSocket.
				[self.asyncSocket disconnect];
			}
			else
			{
				// Cleanup after the last request
				[self finishResponse];
				
				// Prepare for the next request
				// If this assertion fails, it likely means you overrode the
				// finishBody method and forgot to call [super finishBody].
				NSAssert(self.request == nil, @"Request not properly released in finishBody");
				
				self.request = [[HTTPMessage alloc] initEmptyRequest];
				
				numHeaderLines = 0;
				sentResponseHeaders = NO;
				
				// And start listening for more requests
				[self startReadingRequest];
			}
		}
	}
}

/**
 * Sent after the socket has been disconnected.
**/
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	HTTPLogTrace();
	
    [self.socketDelegate socketDidDisconnect];
	self.asyncSocket = nil;
	
	[self die];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HTTPResponse Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method may be called by asynchronous HTTPResponse objects.
 * That is, HTTPResponse objects that return YES in their "- (BOOL)isAsynchronous" method.
 * 
 * This informs us that the response object has generated more data that we may be able to send.
**/
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender
{
	HTTPLogTrace();
	
	// We always dispatch this asynchronously onto our connectionQueue,
	// even if the connectionQueue is the current queue.
	// 
	// We do this to give the HTTPResponse classes the flexibility to call
	// this method whenever they want, even from within a readDataOfLength method.
	
	dispatch_async(connectionQueue, ^{ @autoreleasepool {
		
		if (sender != self.httpResponse)
		{
			HTTPLogWarn(@"%@[%p]: %@ - Sender is not current httpResponse", THIS_FILE, self, THIS_METHOD);
			return;
		}
		
		if (!sentResponseHeaders)
		{
			[self sendResponseHeadersAndBody];
		}
		else
		{
			if (ranges == nil)
			{
				[self continueSendingStandardResponseBody];
			}
			else
			{
				if ([ranges count] == 1)
					[self continueSendingSingleRangeResponseBody];
				else
					[self continueSendingMultiRangeResponseBody];
			}
		}
	}});
}

/**
 * This method is called if the response encounters some critical error,
 * and it will be unable to fullfill the request.
**/
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender
{
	HTTPLogTrace();
	
	// We always dispatch this asynchronously onto our connectionQueue,
	// even if the connectionQueue is the current queue.
	// 
	// We do this to give the HTTPResponse classes the flexibility to call
	// this method whenever they want, even from within a readDataOfLength method.
	dispatch_async(connectionQueue, ^{ @autoreleasepool {
		
		if (sender != self.httpResponse)
		{
			HTTPLogWarn(@"%@[%p]: %@ - Sender is not current httpResponse", THIS_FILE, self, THIS_METHOD);
			return;
		}
		
		[self.asyncSocket disconnectAfterWriting];
	}});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Post Request
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called after each response has been fully sent.
 * Since a single connection may handle multiple request/responses, this method may be called multiple times.
 * That is, it will be called after completion of each response.
**/
- (void)finishResponse
{
	HTTPLogTrace();
	
    [self.delegate connection:self
              didSendResponse:self.httpResponse];
    
	self.request = nil;
	self.httpResponse = nil;
	
	ranges = nil;
	ranges_headers = nil;
	ranges_boundry = nil;
}

/**
 * This method is called after each successful response has been fully sent.
 * It determines whether the connection should stay open and handle another request.
**/
- (BOOL)shouldDie
{
	HTTPLogTrace();
	
	// Override me if you have any need to force close the connection.
	// You may do so by simply returning YES.
	// 
	// If you override this method, you should take care to fall through with [super shouldDie]
	// instead of returning NO.
	
	
	BOOL shouldDie = NO;
	
	NSString *version = [self.request version];
	if ([version isEqualToString:HTTPVersion1_1])
	{
		// HTTP version 1.1
		// Connection should only be closed if request included "Connection: close" header
		
		NSString *connection = [self.request headerField:@"Connection"];
		
		shouldDie = (connection && ([connection caseInsensitiveCompare:@"close"] == NSOrderedSame));
	}
	else if ([version isEqualToString:HTTPVersion1_0])
	{
		// HTTP version 1.0
		// Connection should be closed unless request included "Connection: Keep-Alive" header
		
		NSString *connection = [self.request headerField:@"Connection"];
		
		if (connection == nil)
			shouldDie = YES;
		else
			shouldDie = [connection caseInsensitiveCompare:@"Keep-Alive"] != NSOrderedSame;
	}
	
	return shouldDie;
}

- (void)die
{
	HTTPLogTrace();
	
    [self.delegate connectionWillDie:self];
    
	// Override me if you want to perform any custom actions when a connection is closed.
	// Then call [super die] when you're done.
	// 
	// See also the finishResponse method.
	// 
	// Important: There is a rare timing condition where this method might get invoked twice.
	// If you override this method, you should be prepared for this situation.
	
	// Inform the http response that we're done
	if ([self.httpResponse respondsToSelector:@selector(connectionDidClose)])
	{
		[self.httpResponse connectionDidClose];
	}
	
	// Release the http response so we don't call it's connectionDidClose method again in our dealloc method
	self.httpResponse = nil;
	
	// Post notification of dead connection
	// This will allow our server to release us from its array of connections
	[[NSNotificationCenter defaultCenter] postNotificationName:HTTPConnectionDidDieNotification object:self];
}

@end