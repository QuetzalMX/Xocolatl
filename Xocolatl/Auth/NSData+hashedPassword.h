//
//  NSData+hashedPassword.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/25/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (hashedPassword)

+ (NSData *)SHA256passwordUsing:(NSString *)password
                  andSaltPrefix:(NSString *)salt;

- (NSString *)SHA256String;

@end
