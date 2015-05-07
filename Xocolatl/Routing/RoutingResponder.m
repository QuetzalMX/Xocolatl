//
//  HTTPResponseHandler.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/1/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "RoutingResponder.h"

#import "HTTPMessage.h"
#import "RoutingResponse.h"

@interface RoutingResponder ()

@property (nonatomic, strong) NSMutableDictionary *regexes;
@property (nonatomic, strong) NSMutableDictionary *keys;

@end

@implementation RoutingResponder

- (NSDictionary *)methods;
{
    return nil;
}

- (NSRegularExpression *)regexForMethod:(NSString *)method;
{
    if (!self.regexes) {
        [self prepareRegexesAndKeys];
    }
    
    return self.regexes[method];
}

- (NSArray *)keysForMethod:(NSString *)method;
{
    if (!self.keys) {
        [self prepareRegexesAndKeys];
    }
    
    return self.keys[method];
}

- (void)prepareRegexesAndKeys;
{    
    self.regexes = [NSMutableDictionary new];
    self.keys = [NSMutableDictionary new];
    
    //Each path can contain custom regular expressions and/or variables
    //e.g.
    //validPath with variable: /hello/:name
    //validPath with regular expression: {^/page/(\\d+)}
    __block NSString *parsedPath;
    [self.methods enumerateKeysAndObjectsUsingBlock:^(NSString *method, NSString *path, BOOL *stop) {
        NSMutableArray *keysForMethod = [NSMutableArray array];
        
        if ([path length] > 2 && [path characterAtIndex:0] == '{') {
            //This is a custom regular expression, just remove the {}.
            parsedPath = [path substringWithRange:NSMakeRange(1, [path length] - 2)];
        } else {
            NSRegularExpression *regex = nil;
            
            //Escape regex characters
            regex = [NSRegularExpression regularExpressionWithPattern:@"[.+()]" options:0 error:nil];
            parsedPath = [regex stringByReplacingMatchesInString:path
                                                         options:0
                                                           range:NSMakeRange(0, path.length)
                                                    withTemplate:@"\\\\$0"];
            
            //Parse any :parameters and * in the path
            regex = [NSRegularExpression regularExpressionWithPattern:@"(:(\\w+)|\\*)"
                                                              options:0
                                                                error:nil];
            
            NSMutableString *regexPath = [NSMutableString stringWithString:parsedPath];
            
            __block NSInteger diff = 0;
            [regex enumerateMatchesInString:parsedPath options:0 range:NSMakeRange(0, parsedPath.length)
                                 usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                     NSRange replacementRange = NSMakeRange(diff + result.range.location, result.range.length);
                                     NSString *replacementString = @"(.*?)";
                                     
                                     NSString *capturedString = [parsedPath substringWithRange:result.range];
                                     if ([capturedString isEqualToString:@"*"]) {
                                         [keysForMethod addObject:@"wildcards"];
                                         replacementString = @"(.*?)";
                                     }
                                     else {
                                         NSString *keyString = [parsedPath substringWithRange:[result rangeAtIndex:2]];
                                         [keysForMethod addObject:keyString];
                                         replacementString = @"[/]?([^/]+)";
                                     }
                                     
                                     //Check whether we have to remove the slash.
                                     //The reason we do this is that whenever we have a path like:
                                     // /api/teams/:id
                                     //and we receive a request like
                                     // /api/teams
                                     //the regex does not match because we have included a /
                                     //so comparisons fails.
                                     NSString *fixPathIfDirectory = [regexPath stringByReplacingOccurrencesOfString:capturedString
                                                                                                         withString:@""];
                                     if ([fixPathIfDirectory hasSuffix:@"/"]) {
                                         fixPathIfDirectory = [fixPathIfDirectory substringToIndex:fixPathIfDirectory.length - 1];
                                         fixPathIfDirectory = [fixPathIfDirectory stringByAppendingString:capturedString];
                                         replacementRange = [fixPathIfDirectory rangeOfString:capturedString];
                                         //Since we removed one character, we add one to the length of the range.
                                         replacementRange.length++;
                                     }
                                     
                                     [regexPath replaceCharactersInRange:replacementRange
                                                              withString:replacementString];
                                     diff += replacementString.length - result.range.length;
                                 }];
            
            parsedPath = [NSString stringWithFormat:@"^%@$", regexPath];
        }

        self.keys[method] = keysForMethod;
        self.regexes[method] = [NSRegularExpression regularExpressionWithPattern:parsedPath
                                                                         options:NSRegularExpressionCaseInsensitive
                                                                           error:nil];
    }];
}

#pragma mark - Routing
- (RoutingResponse *)responseForRequest:(HTTPMessage *)message
                         withParameters:(NSDictionary *)parameters;
{
    if (!self.methods[message.method]) {
        return nil;
    }
    
    if ([message.method isEqualToString:@"GET"]) {
        return [self responseForGETRequest:message
                            withParameters:parameters];
    } else if ([message.method isEqualToString:@"POST"]) {
        return [self responseForPOSTRequest:message
                             withParameters:parameters];
    } else if ([message.method isEqualToString:@"PUT"]) {
        return [self responseForPUTRequest:message
                            withParameters:parameters];
    } else if ([message.method isEqualToString:@"DELETE"]) {
        return [self responseForDELETERequest:message
                               withParameters:parameters];
    }
    
    return nil;
}

- (RoutingResponse *)responseForGETRequest:(HTTPMessage *)message
                                    withParameters:(NSDictionary *)parameters;
{
    return nil;
}

- (RoutingResponse *)responseForPOSTRequest:(HTTPMessage *)message
                                     withParameters:(NSDictionary *)parameters;
{
    return nil;
}

- (RoutingResponse *)responseForPUTRequest:(HTTPMessage *)message
                                    withParameters:(NSDictionary *)parameters;
{
    return nil;
}

- (RoutingResponse *)responseForDELETERequest:(HTTPMessage *)message
                                       withParameters:(NSDictionary *)parameters;
{
    return nil;
}

@end