//
//  NSArray+arrayFromNewObjects.h
//  CruyffServer
//
//  Created by Fernando Olivares on 5/7/15.
//  Copyright (c) 2015 Cruyff. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (arrayFromNewObjects)

- (NSArray *)arrayByTransformingObjects:(id (^)(id objectToTransform))transformationBlock;

@end
