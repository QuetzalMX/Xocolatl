//
//  NSArray+transformativeArray.m
//  Xocolatl
//
//  Created by Cuenta on 5/13/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "NSArray+transformativeArray.h"

@implementation NSArray (transformativeArray)

- (NSArray *)arrayByTransformingObjects:(id (^)(id objectToTransform))transformationBlock;
{
    NSMutableArray *sections = [NSMutableArray new];
    [self enumerateObjectsUsingBlock:^(id objectInOriginalArray, NSUInteger idx, BOOL *stop) {
        id transformedObject = transformationBlock(objectInOriginalArray);
        if (transformedObject) {
            [sections addObject:transformedObject];
        }
    }];
    
    return [sections copy];
}

@end
