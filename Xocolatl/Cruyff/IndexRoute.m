//
//  IndexRoute.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "IndexRoute.h"

@implementation IndexRoute

- (NSString *)method;
{
    return @"GET";
}

- (NSString *)path;
{
    return @"/";
}

- (NSString *)dynamicFilePath;
{
    return [self.server.documentRoot stringByAppendingPathComponent:@"index.html"];
}

- (NSDictionary *)replacementDictionary;
{
    return @{@"title": @"Cruyff Football"};
}

@end
