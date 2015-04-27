//
//  HTTPRedirectWithPayload.h
//  Xocolatl
//
//  Created by Fernando Olivares on 4/16/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPDataResponse.h"

@interface HTTPRedirectWithPayload : HTTPDataResponse

- (instancetype)initWithData:(NSData *)data
              andDestination:(NSString *)destination;

@end
