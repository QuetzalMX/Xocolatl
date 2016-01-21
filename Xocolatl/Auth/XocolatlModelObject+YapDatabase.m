//
//  XocolatlModelObject+YapDatabase.m
//  Xocolatl
//
//  Created by Fernando Olivares on 12/28/15.
//  Copyright © 2015 Quetzal. All rights reserved.
//

#import "XocolatlModelObject+YapDatabase.h"
#import "YapDatabase.h"

@implementation XocolatlModelObject (YapDatabase)

#pragma mark - Loading and Saving
+ (instancetype)find:(NSString *)identifier
    usingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    return [transaction objectForKey:identifier
                        inCollection:nil];
}

+ (NSArray *)allObjectsUsingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    NSMutableArray *allObjects = [NSMutableArray new];
    [transaction enumerateKeysAndObjectsInCollection:nil
                                          usingBlock:^(NSString *key, id object, BOOL *stop) {
                                              if (object && [object isMemberOfClass:[self class]]) {
                                                  [allObjects addObject:object];
                                              }
                                          }];
    
    return [allObjects copy];
}

- (BOOL)saveUsingTransaction:(YapDatabaseReadWriteTransaction *)transaction;
{
    self.modifiedAt = [NSDate date];
    
    [transaction setObject:self
                    forKey:self.identifier
              inCollection:nil];
    
    return YES;
}

#pragma mark - JSON
- (NSDictionary *)jsonRepresentationUsingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    return self.jsonRepresentation;
}

@end
