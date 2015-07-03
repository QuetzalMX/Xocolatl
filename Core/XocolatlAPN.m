//
//  XocolatlAPN.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/18/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlAPN.h"

NSString *const XocolatlAPNCustomPayloadKey = @"XocolatlAPNCustomPayloadKey";

@interface XocolatlAPN ()

@property (nonatomic, copy, readwrite) NSString *recipientToken;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *body;
@property (nonatomic, readwrite) NSInteger badgeNumber;
@property (nonatomic, copy, readwrite) NSString *sound;

@end

@implementation XocolatlAPN

+ (instancetype)newNotificationForRecipient:(NSString *)recipientToken
                             WithAlertTitle:(NSString *)title
                                       body:(NSString *)body
                                badgeNumber:(NSInteger)badgeNumber
                                      sound:(NSString *)sound;
{
    if (!title || !body) {
        return nil;
    }
    
    XocolatlAPN *notification = [[XocolatlAPN alloc] init];
    notification.title = title;
    notification.body = body;
    notification.badgeNumber = badgeNumber;
    notification.sound = (sound != nil) ? sound : @"default";
    notification.recipientToken = recipientToken;
    return notification;
}

+ (instancetype)newSilentNotificationForRecipient:(NSString *)recipientToken;
{
    NSParameterAssert(recipientToken);
    XocolatlAPN *notification = [[XocolatlAPN alloc] init];
    notification.sound = @"";
    notification.recipientToken = recipientToken;
    notification.silentNotification = YES;
    notification.priority = XocolatlAPNPriorityConservePower;
    return notification;
}

- (NSDictionary *)rawPayload;
{
    //First, the alert dictionary.
    NSMutableDictionary *alertDictionary = [NSMutableDictionary new];
    
    if (self.title) {
        alertDictionary[@"title"] = self.title;
    }
    
    if (self.body) {
        alertDictionary[@"body"] = self.body;
    }

    if (self.launchImage) {
        alertDictionary[@"launch-image"] = self.launchImage;
    }
    
    //Now, the APS dictionary.
    NSMutableDictionary *apsDictionary = [NSMutableDictionary new];
    
    if (alertDictionary.count > 0)
    {
        apsDictionary[@"alert"] = alertDictionary;
    }
    
    if (self.badgeNumber != XocolatlAPNBadgeNumberNoUpdate) {
        apsDictionary[@"badge"] = @(self.badgeNumber);
    }
    
    if (self.sound) {
        apsDictionary[@"sound"] = self.sound;
    }
    
    if (self.isSilentNotification) {
        apsDictionary[@"content-available"] = @(1);
        apsDictionary[@"priority"] = @5;
    }
    
    //Add any custom payload before the final sending.
    NSMutableDictionary *payload = [@{@"aps": apsDictionary} mutableCopy];
    if (self.customPayload) {
        payload[XocolatlAPNCustomPayloadKey] = self.customPayload;
    }
    
    return [payload copy];
}

@end