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

@property (nonatomic, strong, readwrite) NSDate *createdAt;

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
    
#warning We're using a property here because XocolatlUser needs us to. This sucks.
    self.identifier = [aDecoder decodeObjectForKey:XocolatlModelObjectIdentifierKey];
    _createdAt = [aDecoder decodeObjectForKey:XocolatlModelObjectCreatedAtKey];
    _modifiedAt = [aDecoder decodeObjectForKey:XocolatlModelObjectModifiedAtKey];
    
    return self;
}

- (instancetype)initWithJSON:(id)json;
{
    if (self != [super init]) {
        return nil;
    }
    
    if (json[@"_id"] == nil ||
        json[@"createdAt"] == nil ||
        json[@"modifiedAt"] == nil) {
        return nil;
    }
    
    self.identifier = json[@"_id"];
    
    NSString *createdUnixTimeStamp = json[@"createdAt"];
    if (createdUnixTimeStamp) {
        self.createdAt = [NSDate dateWithTimeIntervalSince1970:[createdUnixTimeStamp doubleValue]];
    }
    
    NSString *modifiedUnixTimeStamp = json[@"modifiedAt"];
    if (modifiedUnixTimeStamp) {
        self.createdAt = [NSDate dateWithTimeIntervalSince1970:[modifiedUnixTimeStamp doubleValue]];
    }
    
    return self;
}

- (void)updateWithJSON:(NSDictionary <NSString *, id> * _Nonnull)json;
{
    self.identifier = json[XocolatlModelObjectIdentifierKey] ?: self.identifier;
    self.createdAt = json[XocolatlModelObjectCreatedAtKey] ?: self.createdAt;
    self.modifiedAt = json[XocolatlModelObjectModifiedAtKey] ?: self.modifiedAt;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.identifier forKey:XocolatlModelObjectIdentifierKey];
    [aCoder encodeObject:self.createdAt forKey:XocolatlModelObjectCreatedAtKey];
    [aCoder encodeObject:self.modifiedAt forKey:XocolatlModelObjectModifiedAtKey];
}

- (NSDictionary <NSString *, id> *)jsonRepresentation;
{
    NSString *createdAt = [NSString stringWithFormat:@"%.0f", [self.createdAt timeIntervalSince1970]];
    NSString *modifiedAt = [NSString stringWithFormat:@"%.0f", [self.modifiedAt timeIntervalSince1970]];
    return @{
             @"_id": self.identifier,
             @"createdAt": createdAt,
             @"modifiedAt": modifiedAt
             };
}

@end