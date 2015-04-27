//
//  CruyffUser.m
//  Xocolatl
//
//  Created by Fernando Olivares on 4/16/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "CruyffUser.h"

@interface CruyffUser ()

@end

@implementation CruyffUser

- (instancetype)initWithCoder:(NSCoder *)aDecoder;
{
    if (self != [super initWithCoder:aDecoder]) {
        return nil;
    }
    
    _email = [aDecoder decodeObjectForKey:@"email"];
    _firstName = [aDecoder decodeObjectForKey:@"firstName"];
    _lastName = [aDecoder decodeObjectForKey:@"lastName"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.email forKey:@"email"];
    [aCoder encodeObject:self.firstName forKey:@"firstName"];
    [aCoder encodeObject:self.lastName forKey:@"lastName"];
}

- (NSDictionary *)jsonRepresentation;
{
    NSMutableDictionary *parentRepresentation = [[super jsonRepresentation] mutableCopy];
    parentRepresentation[@"email"] = self.email;
    parentRepresentation[@"firstName"] = self.firstName;
    parentRepresentation[@"lastName"] = self.lastName;
    
    return [parentRepresentation copy];
}

#pragma mark - Database
- (void)willRegisterUsingRequestBody:(NSDictionary *)requestBody;
{
    self.email = requestBody[@"email"];
    self.firstName = requestBody[@"firstName"];
    self.lastName = requestBody[@"lastName"];
}

@end