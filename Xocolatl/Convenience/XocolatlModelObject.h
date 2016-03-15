//
//  XocolatlModelObject.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol JSONInitializable

/**
 *  Given an NSDictionary with the object's properties, create an object with them.
 *
 *  @param json a dictionary representation of the XocolatlModelObject
 *
 *  @return nil if the dictionary is not valid.
 */
- (instancetype _Nullable)initWithJSON:(NSDictionary <NSString *, id> * _Nonnull)json;

/**
 *  Given an NSDictionary with the object's properties, overwrite _only_ the object's properties found in the dictionary.
 *  This means that if a key is missing from a dictionary, the object's property corresponding to that key will remain untouched.
 *
 *  @param json a dictionary representation of the XocolatlModelObject
 */
- (void)updateWithJSON:(NSDictionary <NSString *, id> * _Nonnull)json;

/**
 *  Returns a dictionary that can be used to build a JSON-representation of the object.
 */
@property (nonatomic, strong, nonnull, readonly) NSDictionary <NSString *, id> *jsonRepresentation;

@end

@interface XocolatlModelObject : NSObject <NSCoding, JSONInitializable>

/**
 *  An identifier is a 36-character (32 without dashes) nonce that is created whenever the object is initialized.
 */
@property (nonatomic, copy, nonnull) NSString *identifier;

/**
 *  createdAt is the date this object was originally initialized. It is persistent between launches.
 */
@property (nonatomic, strong, readonly, nonnull) NSDate *createdAt;

/**
 *  modifiedAt will be changed whenever saveUsingTransaction: is called. It has the same initial value as createdAt until saveUsingTransaction: is called.
 */
@property (nonatomic, strong, nonnull) NSDate *modifiedAt;

@end