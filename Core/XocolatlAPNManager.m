//
//  XocolatlAPNManager.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/15/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlAPNManager.h"

//Push
#import "NWSecTools.h"
#import "NWHub.h"
#import "NWNotification.h"

@interface XocolatlAPNManager () <NWHubDelegate>

@property (nonatomic, strong) NWHub *hub;
@property (nonatomic, strong) NWCertificateRef selectedCertificate;
@property (nonatomic, strong) NWIdentityRef identity;

@end

@implementation XocolatlAPNManager

+ (instancetype)sharedManager;
{
    static XocolatlAPNManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (instancetype)init;
{
    if (self != [super init]) {
        return nil;
    }
    
    
    
    return self;
}

- (BOOL)importP12Certificate:(NSString *)path
                 andPassword:(NSString *)password;
{
    if (!path || !password) {
        return NO;
    }
    
    //Can we parse the p12 file?
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSArray *ids = [NWSecTools identitiesWithPKCS12Data:data
                                               password:password
                                                  error:&error];
    if (!ids) {
        //We couldn't.
        NSLog(@"Unable to read p12 file: %@", error.localizedDescription);
        return NO;
    }
    
    //We could. Let's add the identities.
    self.identity = ids[0];
    self.selectedCertificate = [NWSecTools certificateWithIdentity:ids[0]
                                                             error:&error];
    if (!self.selectedCertificate) {
        NSLog(@"Unable to import p12 file: %@", error.localizedDescription);
        return NO;
    }
    
    //Attempt to connect to the APN service.
    if (self.hub) {
        [self.hub disconnect];
        self.hub = nil;
        NSLog(@"Disconnected from APN");
    }
    
    BOOL sandbox = [NWSecTools isSandboxCertificate:self.selectedCertificate];
    NSString *summary = [NWSecTools summaryWithCertificate:self.selectedCertificate];
    NSLog(@"Connecting to APN..  (%@%@)", summary, sandbox ? @" sandbox" : @"");
    
    NWIdentityRef ident = self.identity ?: [NWSecTools keychainIdentityWithCertificate:self.selectedCertificate
                                                                                 error:&error];
    self.hub = [NWHub connectWithDelegate:self
                                 identity:ident
                                    error:&error];

    //Warning, this code should be in an operation queue.
    if (self.hub) {
        NSLog(@"Connected  (%@%@)", summary, sandbox ? @" sandbox" : @"");
    }
    
    return YES;
}

#pragma mark - Push
- (void)pushAPN:(XocolatlAPN *)notification;
{
#warning This is inneficient, but we can fix it later, as well as catch the object.
    NSData *payload = [NSJSONSerialization dataWithJSONObject:notification.rawPayload
                                                      options:0
                                                        error:nil];
    
    NWNotification *helperNotification = [[NWNotification alloc] initWithPayload:[[NSString alloc] initWithData:payload
                                                                                                       encoding:NSUTF8StringEncoding]
                                                                           token:notification.recipientToken
                                                                      identifier:notification.identifier
                                                                      expiration:[NSDate dateWithTimeIntervalSince1970:notification.expiration]
                                                                        priority:notification.priority];
    NSError *error = nil;
    BOOL pushed = [self.hub pushNotification:helperNotification
                               autoReconnect:YES
                                       error:&error];
    if (pushed) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSError *error = nil;
            NWNotification *failed = nil;
            BOOL read = [self.hub readFailed:&failed
                               autoReconnect:YES
                                       error:&error];
            if (read) {
                if (!failed) {
                    NSLog(@"Payload has been pushed");
                }
            } else {
                NSLog(@"Unable to read failed: %@", error.localizedDescription);
            }
            
            [self.hub trimIdentifiers];
        });
    } else {
        NSLog(@"Unable to push: %@", error.localizedDescription);
        return;
    }
}

#pragma mark - NWHubDelegate
- (void)notification:(NWNotification *)notification didFailWithError:(NSError *)error;
{
    
}

@end
