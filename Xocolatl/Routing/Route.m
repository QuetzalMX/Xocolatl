#import "Route.h"

@interface Route ()

@property (nonatomic, copy, readwrite) NSDictionary *regexes;
@property (nonatomic, copy, readwrite) NSDictionary *keys;

@end

@implementation Route

- (NSTextCheckingResult *)isResponsibleForPath:(NSString *)path;
{
    if (!self.regexes || !self.keys) {
        NSMutableDictionary *routeRegexes = [NSMutableDictionary new];
        NSMutableDictionary *routeKeys = [NSMutableDictionary new];
        [self.methods enumerateKeysAndObjectsUsingBlock:^(NSString *method, NSString *path, BOOL *stop) {
            NSMutableArray *methodKeys = [NSMutableArray new];
            
            if ([path length] > 2 && [path characterAtIndex:0] == '{') {
                // This is a custom regular expression, just remove the {}
                path = [path substringWithRange:NSMakeRange(1, [path length] - 2)];
            } else {
                NSRegularExpression *regex = nil;
                
                // Escape regex characters
                regex = [NSRegularExpression regularExpressionWithPattern:@"[.+()]" options:0 error:nil];
                path = [regex stringByReplacingMatchesInString:path options:0 range:NSMakeRange(0, path.length) withTemplate:@"\\\\$0"];
                
                // Parse any :parameters and * in the path
                regex = [NSRegularExpression regularExpressionWithPattern:@"(:(\\w+)|\\*)"
                                                                  options:0
                                                                    error:nil];
                NSMutableString *regexPath = [NSMutableString stringWithString:path];
                __block NSInteger diff = 0;
                [regex enumerateMatchesInString:path options:0 range:NSMakeRange(0, path.length)
                                     usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                         NSRange replacementRange = NSMakeRange(diff + result.range.location, result.range.length);
                                         NSString *replacementString;
                                         
                                         NSString *capturedString = [path substringWithRange:result.range];
                                         if ([capturedString isEqualToString:@"*"]) {
                                             [methodKeys addObject:@"wildcards"];
                                             replacementString = @"(.*?)";
                                         } else {
                                             NSString *keyString = [path substringWithRange:[result rangeAtIndex:2]];
                                             [methodKeys addObject:keyString];
                                             replacementString = @"([^/]+)";
                                         }
                                         
                                         [regexPath replaceCharactersInRange:replacementRange withString:replacementString];
                                         diff += replacementString.length - result.range.length;
                                     }];
                
                path = [NSString stringWithFormat:@"^%@$", regexPath];
            }
            
            routeRegexes[method] = [NSRegularExpression regularExpressionWithPattern:path options:NSRegularExpressionCaseInsensitive error:nil];
            if (methodKeys.count > 0) {
                routeKeys[method] = methodKeys;
            }
        }];
        
        self.regexes = routeRegexes;
        self.keys = routeKeys;
    }
    
    __block NSTextCheckingResult *result;
    [self.regexes enumerateKeysAndObjectsUsingBlock:^(NSString *method, NSRegularExpression *regex, BOOL *stop) {
        result = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
        *stop = (result != nil);
    }];
    
    return result;
}

- (void)setRegexAndKeys;
{
    NSMutableArray *keys = [NSMutableArray array];
    
    
}

@end
