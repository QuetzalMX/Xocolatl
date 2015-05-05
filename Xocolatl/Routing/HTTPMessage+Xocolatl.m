//
//  HTTPMessage+Xocolatl.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPMessage+Xocolatl.h"

#import <objc/runtime.h>

@implementation HTTPMessage (Xocolatl)

- (void)setCookies:(NSDictionary *)cookies;
{
    objc_setAssociatedObject(self, @selector(cookies), cookies, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)cookies;
{
    NSMutableDictionary *parsedCookies = objc_getAssociatedObject(self, @selector(cookies));
    
    if (!parsedCookies) {
        //Parse the cookies to see if we have an authorized user.
        NSString *cookie = self.allHeaderFields[@"cookie"];
        NSString *cookieWithoutSemiColons = [cookie stringByReplacingOccurrencesOfString:@";"
                                                                              withString:@""];
        NSArray *subCookies = [cookieWithoutSemiColons componentsSeparatedByString:@" "];
        
        NSMutableDictionary *parsedCookies = [NSMutableDictionary new];
        for (NSString *subCookie in subCookies) {
            NSArray *cookieFieldAndValue = [subCookie componentsSeparatedByString:@"="];
            if (cookieFieldAndValue.count < 2) {
                continue;
            }
            
            parsedCookies[cookieFieldAndValue.firstObject] = cookieFieldAndValue.lastObject;
        }
        
        parsedCookies = [parsedCookies copy];
        [self setCookies:parsedCookies];
    }
    
    return parsedCookies;
}

- (void)setParsedBody:(NSDictionary *)cookies;
{
    objc_setAssociatedObject(self, @selector(parsedBody), cookies, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)parsedBody;
{
    NSMutableDictionary *parsedBody = objc_getAssociatedObject(self, @selector(parsedBody));
    
    if (!parsedBody) {
        NSError *unicodeBodyError;
        NSMutableDictionary *unicodeBody = [NSJSONSerialization JSONObjectWithData:self.body
                                                                           options:NSJSONReadingAllowFragments
                                                                             error:&unicodeBodyError];
        if (!unicodeBody || unicodeBodyError) {
            NSString *unicodeBodyString = [[NSString alloc] initWithData:self.body
                                                                encoding:NSUTF8StringEncoding];
            
            NSArray *variablePairs = [unicodeBodyString componentsSeparatedByString:@"&"];
            unicodeBody = [NSMutableDictionary new];
            [variablePairs enumerateObjectsUsingBlock:^(NSString *pair, NSUInteger idx, BOOL *stop) {
                NSArray *pairArray = [pair componentsSeparatedByString:@"="];
                unicodeBody[pairArray.firstObject] = pairArray.lastObject;
            }];
        }
        
        parsedBody = [unicodeBody copy];
        [self setParsedBody:parsedBody];
    }
    
    return parsedBody;
}

@end
