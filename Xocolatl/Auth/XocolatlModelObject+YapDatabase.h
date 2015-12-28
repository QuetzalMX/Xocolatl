//
//  XocolatlModelObject+YapDatabase.h
//  Xocolatl
//
//  Created by Fernando Olivares on 12/28/15.
//  Copyright © 2015 Quetzal. All rights reserved.
//

#import <XocolatlFramework/XocolatlFramework.h>

@class YapDatabaseReadTransaction;
@class YapDatabaseReadWriteTransaction;

@interface XocolatlModelObject (YapDatabase)

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