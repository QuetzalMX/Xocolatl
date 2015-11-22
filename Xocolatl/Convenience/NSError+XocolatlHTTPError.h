//
//  NSError+XocolatlHTTPError.h
//  Xocolatl
//
//  Created by Fernando Olivares on 11/18/15.
//  Copyright © 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XocolatlHTTPResponse.h"

extern NSString * const XocolatlHTTPErrorDomain;

@interface NSError (XocolatlHTTPError)

+ (NSError *)errorWithHTTPCode:(XocolatlHTTPStatusCode)code andReason:(NSString *)reason;

@end
