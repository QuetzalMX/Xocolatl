//
//  HTTPMessage+Xocolatl.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/2/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "HTTPMessage.h"
#import "MultipartFormDataParser.h"

@interface HTTPMessage (Xocolatl) <MultipartFormDataParserDelegate>

- (NSDictionary *)parsedBody;
- (NSDictionary *)cookies;
- (NSImage *)imageFromMultiPartForm;

@end
