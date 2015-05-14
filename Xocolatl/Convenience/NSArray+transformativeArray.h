//
//  NSArray+transformativeArray.h
//  Xocolatl
//
//  Created by Cuenta on 5/13/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (transformativeArray)

- (NSArray *)arrayByTransformingObjects:(id (^)(id objectToTransform))transformationBlock;

@end
