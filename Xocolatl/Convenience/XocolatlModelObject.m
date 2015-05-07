//
//  XocolatlModelObject.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlModelObject.h"

#import "NSString+randomString.h"

static NSString *const XocolatlModelObjectIdentifierKey = @"XocolatlModelObjectIdentifierKey";
static NSString *const XocolatlModelObjectCreatedAtKey = @"XocolatlModelObjectCreatedAtKey";
static NSString *const XocolatlModelObjectModifiedAtKey = @"XocolatlModelObjectModifiedAtKey";

@interface XocolatlModelObject ()

@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, strong, readwrite) NSDate *createdAt;
@property (nonatomic, strong, readwrite) NSDate *modifiedAt;

@end

@implementation XocolatlModelObject

- (instancetype)init;
{
    if (self != [super init]) {
        return nil;
    }
    
    _identifier = [NSString randomString];
    _createdAt = [NSDate date];
    _modifiedAt = [NSDate date];
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder;
{
    if (self != [super init]) {
        return nil;
    }
    
    _identifier = [aDecoder decodeObjectForKey:XocolatlModelObjectIdentifierKey];
    _createdAt = [aDecoder decodeObjectForKey:XocolatlModelObjectCreatedAtKey];
    _modifiedAt = [aDecoder decodeObjectForKey:XocolatlModelObjectModifiedAtKey];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.identifier forKey:XocolatlModelObjectIdentifierKey];
    [aCoder encodeObject:self.createdAt forKey:XocolatlModelObjectCreatedAtKey];
    [aCoder encodeObject:self.modifiedAt forKey:XocolatlModelObjectModifiedAtKey];
}

#pragma mark - Loading and Saving
+ (NSString *)yapDatabaseCollectionIdentifier;
{
    return @"XocolatlModelObjectCollection";
}

+ (instancetype)objectWithIdentifier:(NSString *)identifier
                    usingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    return [transaction objectForKey:identifier
                        inCollection:[[self class] yapDatabaseCollectionIdentifier]];
}

+ (NSArray *)allObjectsUsingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    NSMutableArray *allObjects = [NSMutableArray new];
    [transaction enumerateKeysAndObjectsInCollection:[[self class] yapDatabaseCollectionIdentifier]
                                          usingBlock:^(NSString *key, id object, BOOL *stop) {
                                              if (object) {
                                                  [allObjects addObject:object];
                                              }
                                          }];
    
    return [allObjects copy];
}

- (void)saveUsingTransaction:(YapDatabaseReadWriteTransaction *)transaction;
{
    [transaction setObject:self
                    forKey:self.identifier
              inCollection:[[self class] yapDatabaseCollectionIdentifier]];
    
    self.modifiedAt = [NSDate date];
}

#pragma mark - JSON
- (NSDictionary *)jsonRepresentation;
{
    return @{@"_id": self.identifier,
             @"createdAt": @([self.createdAt timeIntervalSince1970]),
             @"modifiedAt": @([self.modifiedAt timeIntervalSince1970])};
}

- (NSDictionary *)jsonRepresentationUsingTransaction:(YapDatabaseReadTransaction *)transaction;
{
    return [self jsonRepresentation];
}

@end