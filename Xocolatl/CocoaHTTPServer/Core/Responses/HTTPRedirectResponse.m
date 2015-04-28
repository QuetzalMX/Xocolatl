#import "HTTPRedirectResponse.h"
#import "HTTPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_OFF; // | HTTP_LOG_FLAG_TRACE;

@interface HTTPRedirectResponse ()

@property (nonatomic, copy) NSDictionary *headers;

@end

@implementation HTTPRedirectResponse

- (id)initWithPath:(NSString *)redirectPath
        andHeaders:(NSDictionary *)headers;
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		
        NSMutableDictionary *previousHeaders = [[NSDictionary dictionaryWithDictionary:headers] mutableCopy];
        previousHeaders[@"Location"] = redirectPath;
        _headers = [previousHeaders copy];
	}
    
	return self;
}

- (UInt64)contentLength
{
	return 0;
}

- (UInt64)offset
{
	return 0;
}

- (void)setOffset:(UInt64)offset
{
	// Nothing to do
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
	HTTPLogTrace();
	
	return nil;
}

- (BOOL)isDone
{
	return YES;
}

- (NSDictionary *)httpHeaders
{
	HTTPLogTrace();
	
	return self.headers;
}

- (NSInteger)status
{
	HTTPLogTrace();
	
	return 302;
}

- (void)dealloc
{
	HTTPLogTrace();
	
}

@end
