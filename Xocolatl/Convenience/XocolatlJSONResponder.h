//
//  XocolatlResponder.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "DatabaseResponder.h"
#import "XocolatlModelObject.h"

@interface XocolatlJSONResponder : DatabaseResponder

+ (Class)modelClass;

@property (nonatomic, copy, readonly) NSArray *modelObjects;
@property (nonatomic, strong, readonly) XocolatlModelObject *modelObject;

@end
