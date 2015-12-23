//
//  XocolatlModelObject.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlModelObject.h"

#import "NSString+randomString.h"
#import "YapDatabase.h"

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
    return nil;
}

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
                                              if (object) {
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
    NSString *createdAt = [NSString stringWithFormat:@"%.0f", [self.createdAt timeIntervalSince1970]];
    NSString *modifiedAt = [NSString stringWithFormat:@"%.0f", [self.modifiedAt timeIntervalSince1970]];
    return @{@"_id": self.identifier,
             @"createdAt": createdAt,
             @"modifiedAt": modifiedAt};
}

@end