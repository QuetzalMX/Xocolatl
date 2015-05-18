//
//  XocolatlAPNManager.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/15/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XocolatlAPN.h"

@interface XocolatlAPNManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, copy, readonly) NSArray *pushCertificate;

- (BOOL)importP12Certificate:(NSString *)path
                 andPassword:(NSString *)password;

- (void)pushAPN:(XocolatlAPN *)notification;

@end