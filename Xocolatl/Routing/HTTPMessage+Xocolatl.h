//
//  HTTPMessage+Xocolatl.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPMessage.h"

@protocol MultipartFormDataParserDelegate;

@interface HTTPMessage (Xocolatl) <MultipartFormDataParserDelegate>

- (NSDictionary *)parsedBody;
- (NSDictionary *)cookies;
- (NSData *)imageFromMultiPartForm;

@end
