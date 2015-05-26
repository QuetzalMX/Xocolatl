//
//  XocolatlHTTPConnectionDelegate.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/24/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HTTPConnection+Digest.h"

@interface XocolatlHTTPConnectionDelegate : NSObject <HTTPConnectionDelegate, HTTPConnectionRoutingDelegate, HTTPConnectionSecurityDelegate, HTTPConnectionWebSocketDelegate>

@end
