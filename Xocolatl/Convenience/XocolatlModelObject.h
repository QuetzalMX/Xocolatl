//
//  XocolatlModelObject.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YapDatabaseReadTransaction;
@class YapDatabaseReadWriteTransaction;

@interface XocolatlModelObject : NSObject <NSCoding>

/**
 *  An identifier is a 36-character (32 without dashes) nonce that is created whenever the object is initialized.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *identifier;

/**
 *  createdAt is the date this object was originally initialized. It is persistent between launches.
 */
@property (nonatomic, strong, readonly, nonnull) NSDate *createdAt;

/**
 *  modifiedAt will be changed whenever saveUsingTransaction: is called. It has the same initial value as createdAt until saveUsingTransaction: is called.
 */
@property (nonatomic, strong, readonly, nonnull) NSDate *modifiedAt;

/**
 *  This is a query method in order to get all objects of this class from the database. You must provide a transaction in order to fetch them. Internally, this method calls yapDatabaseCollectionIdentifier in order to fetch the objects from the database.
 
    Subclassing this method is optional.
 *
 *  @param transaction a valid read transaction from a server connection.
 *
 *  @return an array of objects that belong to this class.
 */
+ (nonnull NSArray <__kindof XocolatlModelObject *> *)allObjectsUsingTransaction:(nonnull YapDatabaseReadTransaction *)transaction;

/**
 *  This is a query method in order to get one object of this class from the database. You must provide a transaction in order to fetch it. Internally, this method calls yapDatabaseCollectionIdentifier in order to fetch the objects from the database.
 
    Subclassing this method is optional.
 *
 *  @param identifier  a valid identifier
 *  @param transaction a valid read transaction from a server connection.
 *
 *  @return a single object of this class.
 */
+ (nullable instancetype)find:(nonnull NSString *)identifier
             usingTransaction:(nonnull YapDatabaseReadTransaction *)transaction;

/**
 *  This method serializes the object into the default server database. There is really no reason for you to subclass this method. If you want to do something before the object is serialized, you can do so in encodeWithCoder: in your own subclass.
 
    Subclassing this method is optional.
 *
 *  @param transaction a valid readWrite transaction from a server connection.
 */
- (BOOL)saveUsingTransaction:(nonnull YapDatabaseReadWriteTransaction *)transaction;


/**
 *  This method attempts to construct a valid JSON (NSDictionary) object that represents this object's properties. You are encouraged to subclass this method.
 
    NOTE: Remember that you **should** call super when subclassing if you want identifier, createdAt and modifiedAt to be a part of your JSON object.
 *
 *  @param transaction a valid read transaction from a server connection.
 *
 *  @return a dictionary representation of this object.
 */
- (nonnull NSDictionary <NSString *, id> *)jsonRepresentationUsingTransaction:(nonnull YapDatabaseReadTransaction *)transaction;

@end
