#import <Foundation/Foundation.h>
#import "RoutingHTTPServer.h"

@interface Route : NSObject

@property (nonatomic, copy, readonly) NSDictionary *methods;
@property (nonatomic, copy, readonly) NSDictionary *regexes;
@property (nonatomic, copy, readonly) NSDictionary *keys;

@property (nonatomic, copy) RequestHandler handler;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;

- (NSTextCheckingResult *)isResponsibleForPath:(NSString *)path;

@end
