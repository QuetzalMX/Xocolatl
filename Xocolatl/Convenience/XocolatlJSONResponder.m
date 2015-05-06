//
//  XocolatlResponder.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlJSONResponder.h"

#import "RoutingResponse.h"

@implementation XocolatlJSONResponder

+ (Class)modelClass;
{
    return [XocolatlModelObject class];
}

- (RoutingResponse *)responseForGETRequest:(HTTPMessage *)message
                            withParameters:(NSDictionary *)parameters;
{
    __block XocolatlModelObject *modelObject;
    __block NSDictionary *modelObjectJSON;
    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        modelObject = [[[self class] modelClass] objectWithIdentifier:parameters[@"id"]
                                                     usingTransaction:transaction];
        modelObjectJSON = [modelObject jsonRepresentationUsingTransaction:transaction];
    }];
    
    if (!modelObjectJSON) {
        return [RoutingResponse responseWithError:[NSError errorWithDomain:@"Not Found"
                                                                      code:404
                                                                  userInfo:@{@"Reason": @"Player Not Found"}]];
    }
    
    self.modelObject = modelObject;
    return [RoutingResponse responseWithStatus:200
                                       andBody:modelObjectJSON];
}

@end
