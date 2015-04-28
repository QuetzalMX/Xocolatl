#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;
@class HTTPResponseProxy;

typedef void (^ResponseHandler)(NSObject <HTTPResponse> *response, NSDictionary *headers);

@interface RouteResponse : NSObject

@property (nonatomic, assign, readonly) HTTPConnection *connection;
@property (nonatomic, readonly) NSDictionary *headers;
@property (nonatomic, strong) NSObject<HTTPResponse> *response;
@property (nonatomic, readonly) NSObject<HTTPResponse> *proxiedResponse;
@property (nonatomic) NSInteger statusCode;

- (id)initWithConnection:(HTTPConnection *)theConnection
        andResponseBlock:(ResponseHandler)responseBlock;
- (void)setHeader:(NSString *)field value:(NSString *)value;

- (void)setCookieNamed:(NSString *)name
             withValue:(NSString *)value
              isSecure:(BOOL)isSecure
              httpOnly:(BOOL)httpOnly;

- (void)respondWithDictionary:(NSDictionary *)dictionary
                      andCode:(NSInteger)code;
- (void)respondWithString:(NSString *)string;
- (void)respondWithString:(NSString *)string encoding:(NSStringEncoding)encoding;
- (void)respondWithData:(NSData *)data;
- (void)respondWithDynamicFile:(NSString *)path
      andReplacementDictionary:(NSDictionary *)replacementDictionary;
- (void)respondWithFile:(NSString *)path;
- (void)respondWithFile:(NSString *)path async:(BOOL)async;
- (void)respondWithError:(NSError *)error;
- (void)respondWithRedirect:(NSString *)destination;
- (void)respondWithRedirect:(NSString *)destination andData:(NSData *)data;
@end
