//
//  XocolatlAPN.h
//  Xocolatl
//
//  Created by Fernando Olivares on 5/18/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const XocolatlAPNCustomPayloadKey;

typedef NS_ENUM(NSUInteger, XocolatlAPNBadgeNumber) {
    XocolatlAPNBadgeNumberNoUpdate = -1,
};

typedef NS_ENUM(NSUInteger, XocolatlAPNPriority) {
    XocolatlAPNPriorityImmediate = 10,
    XocolatlAPNPriorityConservePower = 5,
};

@interface XocolatlAPN : NSObject

/**
 *  You can read all about notifications here: https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ApplePushService.html
    
    and about being a provider here: https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/CommunicatingWIthAPS.html
 *
 *  @param title       A short string describing the purpose of the notification. Apple Watch displays this string as part of the notification interface. This string is displayed only briefly and should be crafted so that it can be understood quickly. This key was added in iOS 8.2.
 *  @param body        The text of the alert message.
 *  @param badgeNumber The number to display as the badge of the app icon.
 If this property is absent, the badge is not changed. To remove the badge, set the value of this property to 0.
 *  @param sound       The name of a sound file in the app bundle. The sound in this file is played as an alert. If the sound file doesn’t exist or default is specified as the value, the default alert sound is played. The audio must be in one of the audio data formats that are compatible with system sounds; see Preparing Custom Alert Sounds for details.
 *
 *  @return a valid APN object or nil if something went wrong.
 */
+ (instancetype)newNotificationForRecipient:(NSString *)recipientToken
                             WithAlertTitle:(NSString *)title
                                       body:(NSString *)body
                                badgeNumber:(NSInteger)badgeNumber
                                      sound:(NSString *)sound;

+ (instancetype)newSilentNotificationForRecipient:(NSString *)recipientToken;

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *body;
@property (nonatomic, readonly) NSInteger badgeNumber;
@property (nonatomic, copy, readonly) NSString *sound;
@property (nonatomic, copy, readonly) NSString *recipientToken;

/**
 *  Apple Documentation:
    An arbitrary, opaque value that identifies this notification. This identifier is used for reporting errors to your server.
 */
@property (nonatomic) NSInteger identifier;

/**
 *  Apple Documentation:
    A UNIX epoch date expressed in seconds (UTC) that identifies when the notification is no longer valid and can be discarded.
    If this value is non-zero, APNs stores the notification tries to deliver the notification at least once. Specify zero to indicate that the notification expires immediately and that APNs should not store the notification at all.
 */
@property (nonatomic) NSTimeInterval expiration;

/**
 *  Apple Documentation:
    The notification’s priority. Provide one of the following values:
    10 The push message is sent immediately.
    The remote notification must trigger an alert, sound, or badge on the device. It is an error to use this priority for a push that contains only the content-available key.
    5 The push message is sent at a time that conserves power on the device receiving it.
 */
@property (nonatomic) XocolatlAPNPriority priority;

/**
 *  Apple's Documentation:
    A short string describing the purpose of the notification. Apple Watch displays this string as part of the notification interface. This string is displayed only briefly and should be crafted so that it can be understood quickly. This key was added in iOS 8.2.
 */
@property (nonatomic, copy) NSString *alertTitle;

/**
    Apple's Documentation:
    The content-available property with a value of 1 lets the remote notification act as a “silent” notification. When a silent notification arrives, iOS wakes up your app in the background so that you can get new data from your server or do background information processing. Users aren’t told about the new or changed information that results from a silent notification, but they can find out about it the next time they open your app.
 
    To support silent remote notifications, add the remote-notification value to the UIBackgroundModes array in your Info.plist file. To learn more about this array, see UIBackgroundModes.
 */
@property (nonatomic, getter=isSilentNotification) BOOL silentNotification;

/**
 *  You can set a custom dictionary to go along the notification, but you must remember that notifications cannot have a size greater than 2kb after iOS8 and greater than 256 bytes in earlier iOS versions.
 
    When the notification arrives, you can fetch this custom dictionary using the key: XocolatlAPNCustomPayloadKey.
 
    Apple's Documentation:
    Providers can specify custom payload values outside the Apple-reserved aps namespace. Custom values must use the JSON structured and primitive types: dictionary (object), array, string, number, and Boolean. You should not include customer information (or any sensitive data) as custom payload data. Instead, use it for such purposes as setting context (for the user interface) or internal metrics. For example, a custom payload value might be a conversation identifier for use by an instant-message client app or a timestamp identifying when the provider sent the notification. Any action associated with an alert message should not be destructive—for example, it should not delete data on the device.
 */
@property (nonatomic, copy) NSDictionary *customPayload;


/**
 *  Apple Documentation:
    The filename of an image file in the app bundle; it may include the extension or omit it. The image is used as the launch image when users tap the action button or move the action slider. If this property is not specified, the system either uses the previous snapshot,uses the image identified by the UILaunchImageFile key in the app’s Info.plist file, or falls back to Default.png.
 */
@property (nonatomic, copy) NSString *launchImage;

/**
 *  @return a JSON that will be encoded and sent to APN's service.
 */
@property (nonatomic, copy, readonly) NSDictionary *rawPayload;

@end
