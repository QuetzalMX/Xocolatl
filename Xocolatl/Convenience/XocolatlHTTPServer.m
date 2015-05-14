//
//  XocolatlHTTPServer.m
//  Xocolatl
//
//  Created by Fernando Olivares on 5/6/15.
//  Copyright (c) 2015 Quetzal. All rights reserved.
//

#import "XocolatlHTTPServer.h"

#import "SignUpResponder.h"

@implementation XocolatlHTTPServer

+ (instancetype)newServerNamed:(NSString *)name
               listeningAtPort:(NSInteger)port;
{
    return [self newServerNamed:name
                listeningAtPort:port
      usingSSLCertificateAtPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"certificate" ofType:@"p12"]
         andCertificatePassword:@"pass"];
}

+ (instancetype)newServerNamed:(NSString *)name
               listeningAtPort:(NSInteger)port
     usingSSLCertificateAtPath:(NSString *)p12CertificatePath
        andCertificatePassword:(NSString *)certificatePassword;
{
    //Create the server.
    NSString *documentRoot = [[NSString stringWithFormat:@"~/Sites/%@", name] stringByExpandingTildeInPath];
    XocolatlHTTPServer *server = [[XocolatlHTTPServer alloc] initAtPort:port];
    [server setDocumentRoot:documentRoot];
    
    //Let's see if we can create the database.
    NSString *databaseFolderPath = [documentRoot stringByAppendingString:@"/database"];
    BOOL isDirectory = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:databaseFolderPath
                                              isDirectory:&isDirectory]) {
        //The database folder doesn't exist. Create it.
        NSError *databaseFolderCreationError;
        [[NSFileManager defaultManager] createDirectoryAtPath:databaseFolderPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&databaseFolderCreationError];
        if (databaseFolderCreationError) {
            //The database folder couldn't be created. Something is wrong.
            return nil;
        }
    };
    
    //We're good to go. Create our databases.
    NSString *databaseWithFileExtension = [NSString stringWithFormat:@"%@/%@.yap", databaseFolderPath, name];
    server.database = [[YapDatabase alloc] initWithPath:databaseWithFileExtension];
    server.readConnection = [server.database newConnection];
    server.readConnection.permittedTransactions = YDB_AnyReadTransaction;
    
    server.writeConnection = [server.database newConnection];
    server.writeConnection.permittedTransactions = YDB_AnyReadWriteTransaction;
    
    server.sslCertificatePath = p12CertificatePath;
    server.sslCertificatePassword = certificatePassword;
    
    return server;
}

- (void)addDatabaseRoute:(Class)routeClass;
{   
    DatabaseResponder *route = [[routeClass alloc] initWithReadConnection:self.readConnection
                                                       andWriteConnection:self.writeConnection
                                                                 inServer:self];
    if ([route isKindOfClass:[DatabaseResponder class]]) {
        [self addResponseHandler:route];
    }
}

- (void)setSignUpRoute:(Class)signUpRouteClass
         withUserClass:(Class)userClass;
{
    //Note: (FO) isSubclassOfClass checks whether the passed class is a subclas OR it's the same class.
    //So we're safe is someone passes SignUpResponder as the signUpRouteClass.
    NSAssert([signUpRouteClass isSubclassOfClass:[SignUpResponder class]],
             @"Using setSignUpRoute:withUserclass: requires the passed class to be a subclass of SignUpRoute.");
    SignUpResponder *route = [[signUpRouteClass alloc] initWithReadConnection:self.readConnection
                                                           andWriteConnection:self.writeConnection
                                                                     inServer:self
                                                                withUserClass:userClass];
    if (route) {
        [self addResponseHandler:route];
    }
}

@end