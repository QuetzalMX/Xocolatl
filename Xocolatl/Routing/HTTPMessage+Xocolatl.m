//
//  HTTPMessage+Xocolatl.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPMessage+Xocolatl.h"

@implementation HTTPMessage (Xocolatl)

- (NSDictionary *)parsedBody;
{
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
    
    return [unicodeBody copy];
}

@end
