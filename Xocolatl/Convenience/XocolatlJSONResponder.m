//
//  XocolatlResponder.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlJSONResponder.h"

#import "RoutingResponse.h"

@interface XocolatlJSONResponder ()

@property (nonatomic, copy, readwrite) NSArray *modelObjects;
@property (nonatomic, strong, readwrite) XocolatlModelObject *modelObject;

@end

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
    __block NSMutableArray *modelObjects = [NSMutableArray new];
    __block NSArray *modelObjectsJSON;
    NSString *objectId = parameters[@"id"];

    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        //Are we fetching one record or all records?
        if (objectId && objectId.length > 0) {
            //Only one record.
            modelObject = [[[self class] modelClass] objectWithIdentifier:parameters[@"id"]
                                                         usingTransaction:transaction];
            modelObjectJSON = [modelObject jsonRepresentationUsingTransaction:transaction];
        } else {
            //All records.
            [modelObjects addObjectsFromArray:[[[self class] modelClass] allObjectsUsingTransaction:transaction]];
            
            NSMutableArray *fetchedObjectsJSON = [NSMutableArray new];
            [modelObjects enumerateObjectsUsingBlock:^(XocolatlModelObject *fetchedModelObject, NSUInteger idx, BOOL *stop) {
                [fetchedObjectsJSON addObject:[fetchedModelObject jsonRepresentationUsingTransaction:transaction]];
            }];
            
            modelObjectsJSON = fetchedObjectsJSON;
        }
    }];
    
    //What did we fetch?
    if (objectId) {
        
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
    } else {
        //We fetched multiple entries. Can we transform their JSON in data?
        self.modelObjects = modelObjects;
        
        NSError *jsonError;
        NSData *modelObjectsJSONData = [NSJSONSerialization dataWithJSONObject:modelObjectsJSON
                                                                       options:0
                                                                         error:&jsonError];
        if (jsonError) {
            //We couldn't transform it to data.
            return [RoutingResponse responseWithError:[NSError errorWithDomain:@"Server Error"
                                                                          code:500
                                                                      userInfo:@{@"reason": @"Could not get JSON for this object"}]];
        }
        
        return [RoutingResponse responseWithStatus:200
                                           andData:modelObjectsJSONData];
    }
}

@end
