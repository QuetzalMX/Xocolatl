//
//  XocolatlModelObject.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XocolatlModelObject : NSObject <NSCoding>

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


@property (nonatomic, strong, nonnull, readonly) NSDictionary <NSString *, id> *jsonRepresentation;

@end
