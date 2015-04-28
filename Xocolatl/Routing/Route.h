#import <Foundation/Foundation.h>
#import "RoutingHTTPServer.h"

@interface Route : NSObject

@property (nonatomic, copy, readonly) NSString *method;
@property (nonatomic, copy, readonly) NSString *path;

@property (nonatomic) NSRegularExpression *regex;
@property (nonatomic) NSArray *keys;

@property (nonatomic, copy) RequestHandler handler;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;

- (instancetype)initWithMethod:(NSString *)method andPath:(NSString *)path;

@end
