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
@property (nonatomic, copy, readonly) NSString *identifier;

/**
 *  createdAt is the date this object was originally initialized. It is persistent between launches.
 */
@property (nonatomic, strong, readonly) NSDate *createdAt;

/**
 *  modifiedAt must be manually changed. It has the same initial value as createdAt until it is manually modified.
 */
@property (nonatomic, strong, readonly) NSDate *modifiedAt;

/**
 *  All objects saved in the server's default database have a collection value. YapDatabase manages objects not only by its identifier, but optionally by its collection. This way you could, in theory, have two objects with the same identifier, and have no collision issues if they exist in different collections.
 
    Subclassing this method is optional.
 *
 *  @return the collection in which this object is being saved.
 */
+ (NSString *)yapDatabaseCollectionIdentifier;

/**
 *  This is a query method in order to get all objects of this class from the database. You must provide a transaction in order to fetch them. Internally, this method calls yapDatabaseCollectionIdentifier in order to fetch the objects from the database.
 
    Subclassing this method is optional.
 *
 *  @param transaction a valid read transaction from a server connection.
 *
 *  @return an array of objects that belong to this class.
 */
+ (NSArray *)allObjectsUsingTransaction:(YapDatabaseReadTransaction *)transaction;

/**
 *  This is a query method in order to get one object of this class from the database. You must provide a transaction in order to fetch it. Internally, this method calls yapDatabaseCollectionIdentifier in order to fetch the objects from the database.
 
    Subclassing this method is optional.
 *
 *  @param identifier  a valid identifier
 *  @param transaction a valid read transaction from a server connection.
 *
 *  @return a single object of this class.
 */
+ (instancetype)objectWithIdentifier:(NSString *)identifier
                    usingTransaction:(YapDatabaseReadTransaction *)transaction;

/**
 *  This method serializes the object into the default server database. There is really no reason for you to subclass this method. If you want to do something before the object is serialized, you can do so in encodeWithCoder: in your own subclass.
 
    Subclassing this method is optional.
 *
 *  @param transaction a valid readWrite transaction from a server connection.
 */
- (void)saveUsingTransaction:(YapDatabaseReadWriteTransaction *)transaction;


/**
 *  This method attempts to construct a valid JSON (NSDictionary) object that represents this object's properties. You are encouraged to subclass this method.
 
    NOTE: Remember that you **should** call super when subclassing if you want identifier, createdAt and modifiedAt to be a part of your JSON object.
 *
 *  @param transaction a valid read transaction from a server connection.
 *
 *  @return a dictionary representation of this object.
 */
- (NSDictionary *)jsonRepresentationUsingTransaction:(YapDatabaseReadTransaction *)transaction;

@end
