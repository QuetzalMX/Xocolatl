//
//  XocolatlHTTPConnectionDelegate.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/24/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlHTTPConnectionDelegate.h"

#import "HTTPMessage+Xocolatl.h"
#import "HTTPResponse.h"
#import "HTTPVerbs.h"
#import "HTTPAuthenticationRequest.h"
#import "HTTPFileResponse.h"
#import "HTTPConfig.h"
#import "DDData.h"

@implementation XocolatlHTTPConnectionDelegate

#pragma mark - HTTPConnectionDelegate

- (NSDateFormatter *)connectionDateFormatter;
{
    // From Apple's Documentation (Data Formatting Guide -> Date Formatters -> Cache Formatters for Efficiency):
    //
    // "Creating a date formatter is not a cheap operation. If you are likely to use a formatter frequently,
    // it is typically more efficient to cache a single instance than to create and dispose of multiple instances.
    // One approach is to use a static variable."
    //
    // This was discovered to be true in massive form via issue #46:
    //
    // "Was doing some performance benchmarking using instruments and httperf. Using this single optimization
    // I got a 26% speed improvement - from 1000req/sec to 3800req/sec. Not insignificant.
    // The culprit? Why, NSDateFormatter, of course!"
    //
    // Thus, we are using a static NSDateFormatter here.
    static NSDateFormatter *df;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        // Example: Sun, 06 Nov 1994 08:49:37 GMT
        // For some reason, using zzz in the format string produces GMT+00:00
        df = [[NSDateFormatter alloc] init];
        [df setFormatterBehavior:NSDateFormatterBehavior10_4];
        [df setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
        [df setDateFormat:@"EEE, dd MMM y HH:mm:ss 'GMT'"];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
    });
    
    return df;
}

#pragma mark Data
- (void)connection:(HTTPConnection *)connection willReadBodyOfSize:(NSUInteger)bodySize;
{
    //Do something.
}

- (BOOL)connection:(HTTPConnection *)connection shouldAppendData:(NSData *)data;
{
    // HTTPConnection will start appending the data automatically.
    // However, this is only optimal for smaller bodies.
    // If the post is big, such as a file upload, return NO and do your own data processing (you may want to store the file to disk).
    //
    // Remember: In order to support LARGE POST uploads, the data is read in chunks.
    // This prevents a 50 MB upload from being stored in RAM.
    // The size of the chunks are limited by the POST_CHUNKSIZE definition.
    // Therefore, this method may be called multiple times for the same POST request.
    return YES;
}

/**
 * This method is called after the request body has been fully read but before the HTTP request is processed.
 **/
- (void)connection:(HTTPConnection *)connection didReadBodyOfSize:(NSUInteger)bodySize;
{
    // Override me to perform any final operations on an upload.
    // For example, if you were saving the upload to disk this would be
    // the hook to flush any pending data to disk and maybe close the file.
}

#pragma mark Errors
/**
 * Called if we receive some sort of malformed HTTP request.
 * The data parameter is the invalid HTTP header line, including CRLF, as read from GCDAsyncSocket.
 * The data parameter may also be nil if the request as a whole was invalid, such as a POST with no Content-Length.
 **/
- (HTTPMessage *)connection:(HTTPConnection *)connection responseForMalformedRequest:(NSData *)data;
{
    // Override me for custom error handling of invalid HTTP requests
    // If you simply want to add a few extra header fields, see connection:willSendErrorResponse:
    // You can also use connection:willSendErrorResponse: to add an optional HTML body.
    
    // Status Code 400 - Bad Request
    HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:400 description:nil version:HTTPVersion1_1];
    [response setHeaderField:@"Content-Length" value:@"0"];
    [response setHeaderField:@"Connection" value:@"close"];
    
    return response;
}

- (HTTPMessage *)connection:(HTTPConnection *)connection responseForUnsupportedHTTPVersion:(NSString *)unsupportedVersion
{
    HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:505 description:nil version:HTTPVersion1_1];
    [response setHeaderField:@"Content-Length" value:@"0"];
    return response;
}

- (HTTPMessage *)connection:(HTTPConnection *)connection responseForResourceNotFound:(HTTPMessage *)request;
{
    // Status Code 404 - Not Found
    HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:404 description:nil version:HTTPVersion1_1];
    [response setHeaderField:@"Content-Length" value:@"0"];
    return response;
}

- (void)connection:(HTTPConnection *)connection willSendErrorResponse:(HTTPMessage *)response;
{
    // Override me to customize the error response headers
    // You'll likely want to add your own custom headers, and then return [super connection:connection willSendErrorResponse:response]
    //
    // Notes:
    // You can use [response statusCode] to get the type of error.
    // You can use [response setBody:data] to add an optional HTML body.
    // If you add a body, don't forget to update the Content-Length.
    //
    // if ([response statusCode] == 404)
    // {
    //     NSString *msg = @"<html><body>Error 404 - Not Found</body></html>";
    //     NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    //
    //     [response setBody:msgData];
    //
    //     NSString *contentLengthStr = [NSString stringWithFormat:@"%lu", (unsigned long)[msgData length]];
    //     [response setHeaderField:@"Content-Length" value:contentLengthStr];
    // }
    
    // Add standard headers
    NSString *now = [[self connectionDateFormatter] stringFromDate:[NSDate date]];
    [response setHeaderField:@"Date" value:now];
    
    // Add server capability headers
    [response setHeaderField:@"Accept-Ranges" value:@"bytes"];
}

- (void)connection:(HTTPConnection *)connection didSendResponse:(NSObject<HTTPResponse> *)response;
{
    // Override me if you want to perform any custom actions after a response has been fully sent.
    // This is the place to release memory or resources associated with the last request.
    //
    // If you override this method, you should take care to invoke [super finishResponse] at some point.
}

#pragma mark - HTTPConnectionRoutingDelegate
/**
 * This method is called to get a response for a request.
 * You may return any object that adopts the HTTPResponse protocol.
 * The HTTPServer comes with two such classes: HTTPFileResponse and HTTPDataResponse.
 * HTTPFileResponse is a wrapper for an NSFileHandle object, and is the preferred way to send a file response.
 * HTTPDataResponse is a wrapper for an NSData object, and may be used to send a custom response.
 **/
- (NSObject <HTTPResponse> *)responseForConnection:(HTTPConnection *)connection;
{
    // Override me to provide custom responses.
    NSString *filePath = [HTTPFileResponse filePathForURI:connection.requestURI
                                            usingBasePath:connection.config.documentRoot
                                       andValidIndexPages:[NSArray arrayWithObjects:@"index.html", @"index.htm", nil]
                                           allowDirectory:NO];
    
    BOOL isDir = NO;
    
    if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
    {
        return [[HTTPFileResponse alloc] initWithFilePath:filePath forConnection:connection];
        
        // Use me instead for asynchronous file IO.
        // Generally better for larger files.
        //	return [[[HTTPAsyncFileResponse alloc] initWithFilePath:filePath forConnection:self] autorelease];
    }
    
    return nil;
}

- (void)connection:(HTTPConnection *)connection willRespondUsing:(HTTPMessage *)response;
{
    // Add standard headers
    NSString *now = [[self connectionDateFormatter] stringFromDate:[NSDate date]];
    [response setHeaderField:@"Date" value:now];
    
    // Add server capability headers
    [response setHeaderField:@"Accept-Ranges" value:@"bytes"];
}

- (BOOL)connection:(HTTPConnection *)connection acceptsMethod:(NSString *)method atPath:(NSString *)path;
{
    // Things you may want to consider:
    // - Does the given path represent a resource that is designed to accept this method?
    // - If accepting an upload, is the size of the data being uploaded too big?
    //   To do this you can check the requestContentLength variable.
    //
    // See also: expectsRequestBodyFromMethod:atPath:
    
    if ([method isEqualToString:HTTPVerbGET])
        return YES;
    
    if ([method isEqualToString:HTTPVerbHEAD])
        return YES;
    
    return NO;
}

- (HTTPMessage *)connection:(HTTPConnection *)connection responseForUnknownMethod:(NSString *)method atPath:(NSString *)path;
{
    // If you simply want to add a few extra header fields, see connection:willSendErrorResponse:
    // You can also use connection:willSendErrorResponse: to add an optional HTML body.
    
    // Status Code 400 - Bad Request
    HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:405 description:nil version:HTTPVersion1_1];
    [response setHeaderField:@"Content-Length" value:@"0"];
    [response setHeaderField:@"Connection" value:@"close"];
    
    return response;
}

#pragma mark - HTTPConnectionSecurityDelegate
/**
 * Returns whether or not the server is configured to be a secure server.
 * In other words, all connections to this server are immediately secured, thus only secure connections are allowed.
 * This is the equivalent of having an https server, where it is assumed that all connections must be secure.
 * If this is the case, then unsecure connections will not be allowed on this server, and a separate unsecure server
 * would need to be run on a separate port in order to support unsecure connections.
 *
 * Note: In order to support secure connections, the sslIdentityAndCertificates method must be implemented.
 **/
- (BOOL)hasHTTPSEnabled;
{
    return YES;
}

/**
 * This method is expected to returns an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
 * It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
 **/
- (NSArray *)sslIdentityAndCertificates;
{
    return nil;
}

/**
 * Returns the authentication realm.
 * In this generic implmentation, a default realm is used for the entire server.
 **/
- (NSString *)authenticationRealmForConnection:(HTTPConnection *)connection;
{
    return @"defaultRealm@host.com";
}

- (HTTPConnectionSecurityAuthenticationType)connection:(HTTPConnection *)connection
                                      authLevelForPath:(NSString *)path;
{
    return HTTPConnectionSecurityAuthenticationTypeNone;
}

- (BOOL)connection:(HTTPConnection *)connection validateCredentialsForAccessToPath:(NSString *)path
   withAccessLevel:(HTTPConnectionSecurityAuthenticationType)authenticationType;
{
    // Extract the authentication information from the Authorization header
    HTTPAuthenticationRequest *auth = [[HTTPAuthenticationRequest alloc] initWithRequest:connection.request];
    
    if (authenticationType == HTTPConnectionSecurityAuthenticationTypeDigest)
    {
        // Digest Access Authentication (RFC 2617)
        if(!auth.isDigest)
        {
            // User didn't send proper digest access authentication credentials
            return NO;
        }
        
        if (!auth.username)
        {
            // The client didn't provide a username.
            // Most likely they didn't provide any authentication at all.
            return NO;
        }
        
#warning Get the user's password from your database here.
        NSString *password = @"password";
        if (!password)
        {
            // No access allowed (username doesn't exist in system)
            return NO;
        }
        
        NSString *url = [connection.request.url relativeString];
        if (![url isEqualToString:[auth uri]])
        {
            // Requested URL and Authorization URI do not match
            // This could be a replay attack
            // IE - attacker provides same authentication information, but requests a different resource
            return NO;
        }
        
        // The nonce the client provided will most commonly be stored in our local (cached) nonce variable
        if (![connection.nonce isEqualToString:auth.nonce])
        {
            // The given nonce may be from another connection.
            // We need to search our list of recent nonce strings that have been recently distributed.
            if ([HTTPConnection hasRecentNonce:auth.nonce])
            {
                // Store nonce in local (cached) nonce variable to prevent array searches in the future
                connection.nonce = [[auth nonce] copy];
                
                // The client has switched to using a different nonce value
                // This may happen if the client tries to get a file in a directory with different credentials.
                // The previous credentials wouldn't work, and the client would receive a 401 error
                // along with a new nonce value. The client then uses this new nonce value and requests the file again.
                // Whatever the case may be, we need to reset lastNC, since that variable is on a per nonce basis.
                connection.lastNC = 0;
            }
            else
            {
                // We have no knowledge of ever distributing such a nonce.
                // This could be a replay attack from a previous connection in the past.
                return NO;
            }
        }
        
        long authNC = strtol([[auth nc] UTF8String], NULL, 16);
        
        if (authNC <= connection.lastNC)
        {
            // The nc value (nonce count) hasn't been incremented since the last request.
            // This could be a replay attack.
            return NO;
        }
        
        connection.lastNC = authNC;
        
        NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", auth.username, auth.realm, password];
        NSString *HA2str = [NSString stringWithFormat:@"%@:%@", connection.request.method, auth.uri];
        
        NSString *HA1 = [[[HA1str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
        
        NSString *HA2 = [[[HA2str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
        
        NSString *responseStr = [NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@",
                                 HA1, [auth nonce], [auth nc], [auth cnonce], [auth qop], HA2];
        
        NSString *response = [[[responseStr dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
        
        return [response isEqualToString:[auth response]];
    }
    else
    {
        // Basic Authentication
        
        if (![auth isBasic])
        {
            // User didn't send proper base authentication credentials
            return NO;
        }
        
        // Decode the base 64 encoded credentials
        NSString *base64Credentials = [auth base64Credentials];
        
        NSData *temp = [[base64Credentials dataUsingEncoding:NSUTF8StringEncoding] base64Decoded];
        
        NSString *credentials = [[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding];
        
        // The credentials should be of the form "username:password"
        // The username is not allowed to contain a colon
        
        NSRange colonRange = [credentials rangeOfString:@":"];
        
        if (colonRange.length == 0)
        {
            // Malformed credentials
            return NO;
        }
        
        NSString *credUsername = [credentials substringToIndex:colonRange.location];
        NSString *credPassword = [credentials substringFromIndex:(colonRange.location + colonRange.length)];
#warning Get the user's password from your database here.
        NSString *password = @"password";
        if (!credUsername || !password)
        {
            // No access allowed (username doesn't exist in system)
            return NO;
        }
        
        return [password isEqualToString:credPassword];
    }
    
    return YES;
}

- (HTTPMessage *)connection:(HTTPConnection *)connection
failedToAuthenticateForPath:(NSString *)path
            withAccessLevel:(HTTPConnectionSecurityAuthenticationType)authenticationType;
{
    HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:401 description:nil version:HTTPVersion1_1];
    [response setHeaderField:@"Content-Length" value:@"0"];
    return response;
}

#pragma mark - Sockets
- (WebSocket *)connectionWillTransitionToSocket:(HTTPConnection *)connection;
{
    // Override me to provide custom WebSocket responses.
    // To do so, simply override the base WebSocket implementation, and add your custom functionality.
    // Then return an instance of your custom WebSocket here.
    //
    // For example:
    //
    // if ([path isEqualToString:@"/myAwesomeWebSocketStream"])
    // {
    //     return [[[MyWebSocket alloc] initWithRequest:request socket:asyncSocket] autorelease];
    // }
    //
    // return [super webSocketForURI:path];
    
    return nil;
}

@end
