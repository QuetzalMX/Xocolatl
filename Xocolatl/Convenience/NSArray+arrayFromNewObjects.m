//
//  NSArray+arrayFromNewObjects.m
//  CruyffServer
//
//  Created by Fernando Olivares on 5/7/15.
//  Copyright (c) 2015 Cruyff. All rights reserved.
//

#import "NSArray+arrayFromNewObjects.h"

@implementation NSArray (arrayFromNewObjects)

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
