//
//  BonjourHTTPServer.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/22/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "BonjourHTTPServer.h"

#import "HTTPLogging.h"

static const int httpLogLevel = HTTP_LOG_LEVEL_INFO; // | HTTP_LOG_FLAG_TRACE;

@interface BonjourHTTPServer ()

@property (nonatomic, strong) NSNetService *netService;
@property (nonatomic, copy) NSDictionary *txtRecordDictionary;

@end

@implementation BonjourHTTPServer

@synthesize domain = _domain;
@synthesize name = _name;
@synthesize type = _type;

- (instancetype)init;
{
    if (self != [super init])
    {
        return nil;
    }
    
    // Bonjour domain. Use the local domain by default
    _domain = @"local.";
    
    // If using an empty string ("") for the service name when registering,
    // the system will automatically use the "Computer Name".
    // Passing in an empty string will also handle name conflicts
    // by automatically appending a digit to the end of the name.
    _name = @"";
    
    return self;
}

/**
 * Domain on which to broadcast this service via Bonjour.
 * The default domain is @"local".
 **/
- (NSString *)domain
{
    __block NSString *result;
    
    dispatch_sync(self.serverQueue, ^{
        result = _domain;
    });
    
    return result;
}

- (void)setDomain:(NSString *)value
{
    HTTPLogTrace();
    
    NSString *valueCopy = [value copy];
    
    dispatch_async(self.serverQueue, ^{
        _domain = valueCopy;
    });
    
}

/**
 * The name to use for this service via Bonjour.
 * The default name is an empty string,
 * which should result in the published name being the host name of the computer.
 **/
- (NSString *)name
{
    __block NSString *result;
    
    dispatch_sync(self.serverQueue, ^{
        result = _name;
    });
    
    return result;
}

- (NSString *)publishedName
{
    __block NSString *result;
    
    dispatch_sync(self.serverQueue, ^{
        
        if (self.netService == nil)
        {
            result = nil;
        }
        else
        {
            
            dispatch_block_t bonjourBlock = ^{
                result = [self.netService.name copy];
            };
            
            [[self class] performBonjourBlock:bonjourBlock];
        }
    });
    
    return result;
}

- (void)setName:(NSString *)value
{
    NSString *valueCopy = [value copy];
    
    dispatch_async(self.serverQueue, ^{
        _name = valueCopy;
    });
    
}

/**
 * The type of service to publish via Bonjour.
 * No type is set by default, and one must be set in order for the service to be published.
 **/
- (NSString *)type
{
    __block NSString *result;
    
    dispatch_sync(self.serverQueue, ^{
        result = _type;
    });
    
    return result;
}

- (void)setType:(NSString *)value
{
    NSString *valueCopy = [value copy];
    
    dispatch_async(self.serverQueue, ^{
        _type = valueCopy;
    });
    
}

/**
 * The extra data to use for this service via Bonjour.
 **/
- (NSDictionary *)TXTRecordDictionary
{
    __block NSDictionary *result;
    
    dispatch_sync(self.serverQueue, ^{
        result = _txtRecordDictionary;
    });
    
    return result;
}

- (void)setTXTRecordDictionary:(NSDictionary *)value
{
    HTTPLogTrace();
    
    NSDictionary *valueCopy = [value copy];
    
    dispatch_async(self.serverQueue, ^{
        
        _txtRecordDictionary = valueCopy;
        
        // Update the txtRecord of the netService if it has already been published
        if (self.netService)
        {
            NSData *txtRecordData = nil;
            if (_txtRecordDictionary)
                txtRecordData = [NSNetService dataFromTXTRecordDictionary:_txtRecordDictionary];
            
            dispatch_block_t bonjourBlock = ^{
                [self.netService setTXTRecordData:txtRecordData];
            };
            
            [[self class] performBonjourBlock:bonjourBlock];
        }
    });
}

#pragma mark - Server Control
- (BOOL)start:(NSError *__autoreleasing *)errPtr;
{
    BOOL start = [super start:errPtr];
    if (start)
    {
        [self publishBonjour];
    }
    
    return start;
}

- (void)stop:(BOOL)keepExistingConnections;
{
    [self unpublishBonjour];
    [super stop:keepExistingConnections];
}

#pragma mark Bonjour
- (void)publishBonjour
{
    HTTPLogTrace();
    NSAssert(self.isOnServerQueue, @"Must be on serverQueue");
    if (!self.type)
    {
        return;
    }
    
    self.netService = [[NSNetService alloc] initWithDomain:self.domain
                                                      type:self.type
                                                      name:self.name
                                                      port:(int)self.listeningPort];
    [self.netService setDelegate:self];
    
    NSData *txtRecordData = nil;
    if (self.txtRecordDictionary)
    {
        txtRecordData = [NSNetService dataFromTXTRecordDictionary:self.txtRecordDictionary];
    }
    
    dispatch_block_t bonjourBlock = ^{
        
        [self.netService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [self.netService publish];
        
        // Do not set the txtRecordDictionary prior to publishing!!!
        // This will cause the OS to crash!!!
        if (txtRecordData)
        {
            [self.netService setTXTRecordData:txtRecordData];
        }
    };
    
    [[self class] startBonjourThreadIfNeeded];
    [[self class] performBonjourBlock:bonjourBlock];
}

- (void)unpublishBonjour
{
    HTTPLogTrace();
    
    NSAssert(self.isOnServerQueue, @"Must be on serverQueue");
    
    if (!self.netService)
    {
        return;
    }
    
    dispatch_block_t bonjourBlock = ^{
        [self.netService stop];
    };
    
    [[self class] performBonjourBlock:bonjourBlock];

    self.netService = nil;
}

/**
 * Republishes the service via bonjour if the server is running.
 * If the service was not previously published, this method will publish it (if the server is running).
 **/
- (void)republishBonjour
{
    HTTPLogTrace();
    
    dispatch_async(self.serverQueue, ^{
        
        [self unpublishBonjour];
        [self publishBonjour];
    });
}

/**
 * Called when our bonjour service has been successfully published.
 * This method does nothing but output a log message telling us about the published service.
 **/
- (void)netServiceDidPublish:(NSNetService *)ns
{
    // Override me to do something here...
    //
    // Note: This method is invoked on our bonjour thread.
    
    HTTPLogInfo(@"Bonjour Service Published: domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
}

/**
 * Called if our bonjour service failed to publish itself.
 * This method does nothing but output a log message telling us about the published service.
 **/
- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
    // Override me to do something here...
    // 
    // Note: This method in invoked on our bonjour thread.
    
    HTTPLogWarn(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@",
                [ns domain], [ns type], [ns name], errorDict);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour Thread
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * NSNetService is runloop based, so it requires a thread with a runloop.
 * This gives us two options:
 *
 * - Use the main thread
 * - Setup our own dedicated thread
 *
 * Since we have various blocks of code that need to synchronously access the netservice objects,
 * using the main thread becomes troublesome and a potential for deadlock.
 **/

static NSThread *bonjourThread;

+ (void)startBonjourThreadIfNeeded
{
    HTTPLogTrace();
    
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        
        HTTPLogVerbose(@"%@: Starting bonjour thread...", THIS_FILE);
        
        bonjourThread = [[NSThread alloc] initWithTarget:self
                                                selector:@selector(bonjourThread)
                                                  object:nil];
        [bonjourThread start];
    });
}

+ (void)bonjourThread
{
    @autoreleasepool {
        
        HTTPLogVerbose(@"%@: BonjourThread: Started", THIS_FILE);
        
        // We can't run the run loop unless it has an associated input source or a timer.
        // So we'll just create a timer that will never fire - unless the server runs for 10,000 years.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        [NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow]
                                         target:self
                                       selector:@selector(donothingatall:)
                                       userInfo:nil
                                        repeats:YES];
#pragma clang diagnostic pop
        
        [[NSRunLoop currentRunLoop] run];
        
        HTTPLogVerbose(@"%@: BonjourThread: Aborted", THIS_FILE);
        
    }
}

+ (void)executeBonjourBlock:(dispatch_block_t)block
{
    HTTPLogTrace();
    
    NSAssert([NSThread currentThread] == bonjourThread, @"Executed on incorrect thread");
    
    block();
}

+ (void)performBonjourBlock:(dispatch_block_t)block
{
    HTTPLogTrace();
    
    [self performSelector:@selector(executeBonjourBlock:)
                 onThread:bonjourThread
               withObject:block
            waitUntilDone:YES];
}

@end
