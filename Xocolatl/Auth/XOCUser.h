//
//  XOCUser.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/14/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XOCUser : NSObject

+ (instancetype)newUserWithUsername:(NSString *)username
                        andPassword:(NSString *)password;

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *username;

@end
