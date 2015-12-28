//
//  XOCUsersResponder.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XOCUsersResponder.h"

#import "XocolatlUser.h"
#import "XocolatlHTTPResponse.h"
#import "YapDatabase.h"
#import "HTTPVerbs.h"

#import "XocolatlModelObject+YapDatabase.h"

@interface XOCUsersResponder ()

@property (nonatomic, strong, readwrite) XocolatlModelObject *modelObject;

@end

@implementation XOCUsersResponder

@synthesize modelObject = _modelObject;

- (NSDictionary *)methods;
{
    return @{HTTPVerbGET: @"/api/users/:username"};
}

- (BOOL)isProtected:(NSString *)method;
{
    return YES;
}

- (RoutingResponse *)responseForGETRequest:(HTTPMessage *)message
                            withParameters:(NSDictionary *)parameters;
{
    __block XocolatlUser *modelObject;
    __block NSDictionary *modelObjectJSON;
    NSString *objectId = parameters[@"username"];
    
    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        //Only one record.
        modelObject = [XocolatlUser find:objectId
                        usingTransaction:transaction];
        modelObjectJSON = [modelObject jsonRepresentationUsingTransaction:transaction];
    }];
    
    //Did we fetch something from the database?
    if (!modelObjectJSON) {
        //Nope. Send an error.
        return [XocolatlHTTPResponse responseWithErrorCode:XocolatlHTTPStatusCode404NotFound
                                                    reason:@"User not found."];
    }
    
    //We fetched one entry.
    self.modelObject = modelObject;
    return [RoutingResponse responseWithStatus:XocolatlHTTPStatusCode200OK
                                       andBody:modelObjectJSON];
}

@end
