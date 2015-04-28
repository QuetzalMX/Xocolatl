#import <Foundation/Foundation.h>
#import "HTTPResponse.h"


@interface HTTPRedirectResponse : NSObject <HTTPResponse>

- (id)initWithPath:(NSString *)redirectPath
        andHeaders:(NSDictionary *)headers;

@end
