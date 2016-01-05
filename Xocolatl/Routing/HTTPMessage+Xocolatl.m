//
//  HTTPMessage+Xocolatl.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPMessage+Xocolatl.h"

#import <objc/runtime.h>
#import <AppKit/AppKit.h>
#import "MultipartFormDataParser.h"

NSString *const XocolatlHTTPHeaderContentType = @"Content-Type";

@implementation HTTPMessage (Xocolatl)

- (void)setImageFromMultiPartForm:(NSData *)image;
{
    objc_setAssociatedObject(self, @selector(imageFromMultiPartForm), image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSData *)imageFromMultiPartForm;
{
    if (!objc_getAssociatedObject(self, @selector(imageFromMultiPartForm)))
    {
        //Get the boundary from our header.
        NSString *boundary = self.allHeaderFields[XocolatlHTTPHeaderContentType];
        boundary = [[[boundary componentsSeparatedByString:@"="] lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        MultipartFormDataParser *dataParser = [[MultipartFormDataParser alloc] initWithBoundary:boundary
                                                                                   formEncoding:NSASCIIStringEncoding];
        dataParser.delegate = self;
        [dataParser appendData:self.body];
        
        //NOTE: (FO) By now, we should already have the associated property set, so we're done.
    }
    
    return objc_getAssociatedObject(self, @selector(imageFromMultiPartForm));
}

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
        NSString *sanitizedCookie = [cookie stringByReplacingOccurrencesOfString:@"\""
                                                                      withString:@""];
        NSString *cookieWithoutSemiColons = [sanitizedCookie stringByReplacingOccurrencesOfString:@";"
                                                                                       withString:@""];
        NSArray *subCookies = [cookieWithoutSemiColons componentsSeparatedByString:@" "];
        
        NSMutableDictionary *parsedCookies = [NSMutableDictionary new];
        for (NSString *subCookie in subCookies) {
            //Find the first = sign.
            NSRange equalSignRange = [subCookie rangeOfString:@"="];
            
            if (equalSignRange.location == NSNotFound || equalSignRange.location + 1 >= subCookie.length) {
                continue;
            }
            
            NSString *cookieName = [subCookie substringToIndex:equalSignRange.location];
            NSString *cookieValue = [subCookie substringFromIndex:equalSignRange.location + 1];
            if (!cookieName || !cookieValue) {
                continue;
            }
            
            parsedCookies[cookieName] = cookieValue;
        }
        
        [self setCookies:parsedCookies];
    }
    
    //NOTE: (FO) For a reason I don't understand, if we generate parsedCookies, we'll be able to see it as long as it's inside the if. Once we leave the if, its value is reset to nil. This is why we do a little bit of recursion here.
    if (!parsedCookies) {
        return self.cookies;
    } else {
        return parsedCookies;
    }
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
                
                NSString *key = pairArray.firstObject;
                key = [key stringByRemovingPercentEncoding];
                key = [[key componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
                
                NSString *value = pairArray.lastObject;
                value = [value stringByRemovingPercentEncoding];
                
                unicodeBody[key] = value;
            }];
        }
        
        parsedBody = [unicodeBody copy];
        [self setParsedBody:parsedBody];
    }
    
    return parsedBody;
}

#pragma mark - MultipartFormDataparser
- (void) processContent:(NSData*) data WithHeader:(MultipartMessageHeader*) header;
{
    if ([[NSImage alloc] initWithData:data])
    {
        self.imageFromMultiPartForm = data;
    }
}

@end