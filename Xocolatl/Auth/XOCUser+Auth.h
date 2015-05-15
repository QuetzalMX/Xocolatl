//
//  XOCUser+Auth.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/16/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlUser.h"

@interface XocolatlUser (Auth)

- (void)willRegisterUsingRequestBody:(NSDictionary *)requestBody;

@end