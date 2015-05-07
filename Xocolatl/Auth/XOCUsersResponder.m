//
//  XOCUsersResponder.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XOCUsersResponder.h"

#import "XOCUser.h"
#import "RoutingResponse.h"

@interface XOCUsersResponder ()

@property (nonatomic, strong, readwrite) XocolatlModelObject *modelObject;

@end

@implementation XOCUsersResponder

@synthesize modelObject = _modelObject;

- (NSDictionary *)methods;
{
    return @{@"GET": @"/api/users/:username"};
}

- (BOOL)isProtected:(NSString *)method;
{
    return YES;
}

- (RoutingResponse *)responseForGETRequest:(HTTPMessage *)message
                            withParameters:(NSDictionary *)parameters;
{
    __block XOCUser *modelObject;
    __block NSDictionary *modelObjectJSON;
    NSString *objectId = parameters[@"username"];
    
    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        //Only one record.
        modelObject = [XOCUser objectWithIdentifier:objectId
                                   usingTransaction:transaction];
        modelObjectJSON = [modelObject jsonRepresentationUsingTransaction:transaction];
    }];
    
    //Did we fetch something from the database?
    if (!modelObjectJSON) {
        //Nope. Send an error.
        return [RoutingResponse responseWithError:[NSError errorWithDomain:@"Not Found"
                                                                      code:404
                                                                  userInfo:@{@"Reason": @"Object Not Found"}]];
    }
    
    //We fetched one entry.
    self.modelObject = modelObject;
    return [RoutingResponse responseWithStatus:200
                                       andBody:modelObjectJSON];
}

@end
