//
//  DynamicFileRoute.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/28/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "AdvancedRoute.h"

@interface DynamicFileRoute : AdvancedRoute

@property (nonatomic, copy, readonly) NSString *dynamicFilePath;
@property (nonatomic, copy, readonly) NSDictionary *replacementDictionary;

@end