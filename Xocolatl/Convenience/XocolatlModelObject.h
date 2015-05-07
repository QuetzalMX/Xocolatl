//
//  XocolatlModelObject.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YapDatabase.h"

@interface XocolatlModelObject : NSObject <NSCoding>

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, strong, readonly) NSDate *createdAt;
@property (nonatomic, strong, readonly) NSDate *modifiedAt;

//Database
+ (NSString *)yapDatabaseCollectionIdentifier;

//Load
+ (NSArray *)allObjectsUsingTransaction:(YapDatabaseReadTransaction *)transaction;
+ (instancetype)objectWithIdentifier:(NSString *)identifier
                    usingTransaction:(YapDatabaseReadTransaction *)transaction;

//Save
- (void)saveUsingTransaction:(YapDatabaseReadWriteTransaction *)transaction;

//JSON.
- (NSDictionary *)jsonRepresentationUsingTransaction:(YapDatabaseReadTransaction *)transaction;

@end
