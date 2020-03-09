//
//  URLEndpointListenerTest.m
//  CBL ObjC Tests
//
//  Created by Jayahari Vavachan on 3/3/20.
//  Copyright © 2020 Couchbase. All rights reserved.
//

#import "ReplicatorTest.h"

#ifndef COUCHBASE_ENTERPRISE
#error Couchbase Lite EE Only
#endif

@interface URLEndpointListenerTest : ReplicatorTest

@end

@implementation URLEndpointListenerTest

#pragma mark - Helper methods
- (CBLURLEndpointListener*) listenTo: (NSString*)network
                                port: (uint16)port
                            database: (CBLDatabase*)database {
    CBLURLEndpointListener* listener;
    CBLURLEndpointListenerConfiguration* config;
    if (network) {
        config = [[CBLURLEndpointListenerConfiguration alloc] initWithDatabase: database
                                                                          port: port
                                                              networkInterface: network
                                                                      identity: nil];
    } else {
        config = [[CBLURLEndpointListenerConfiguration alloc] initWithDatabase: database
                                                                          port: port
                                                                      identity: nil];
    }
    
    listener = [[CBLURLEndpointListener alloc] initWithConfig: config];
    
    NSError* err = nil;
    [listener startWithError: &err];
    return listener;
}

#pragma mark - Basic Tests

- (void) testCustomPort {
    CBLDatabase.log.console.level = kCBLLogLevelInfo;
    NSString* urlString = [NSString stringWithFormat: @"ws://localhost:5666/%@", otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listenTo: nil port: 5666 database: otherDB];

    [self generateDocumentWithID: @"doc-1"];
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    id config = [self configWithTarget: target type: kCBLReplicatorTypePush continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual(otherDB.count, 1);
    
    // TODO: get and verify the ports are same!
    
    [list stop];
}

- (void) testCustomNetworkInterface {
    NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listenTo: url.host port: 8080 database: otherDB];

    [self generateDocumentWithID: @"doc-1"];
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    id config = [self configWithTarget: target type: kCBLReplicatorTypePush continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual(otherDB.count, 1);
    
    // TODO: check the custom network interface is same!
    
    [list stop];
}

- (void) testMultipleListenerOnDifferentDBs {
    NSMutableArray<CBLURLEndpointListener*>* lists = [NSMutableArray array];
    NSMutableArray<CBLDatabase*>* dbs = [NSMutableArray array];
    for (uint16 i = 0; i < 10; i++) {
        NSString* name = [NSString stringWithFormat: @"dbName-%d", i];
        NSError* err = nil;
        CBLDatabase* tempDB = [[CBLDatabase alloc] initWithName: name error: &err];
        
        [lists addObject: [self listenTo: @"127.0.0.1" port: 8080 + i database: tempDB]];
        [dbs addObject: tempDB];
    }
    [self generateDocumentWithID: @"doc-1"];
    
    for (uint16 i = 0; i < 10; i++) {
        NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:%d/%@", (8080 + i), [dbs objectAtIndex: i].name];
        NSURL* url = [[NSURL alloc] initWithString: urlString];
        CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
        id config = [self configWithTarget: target type: kCBLReplicatorTypePush continuous: NO];
        [self run: config errorCode: 0 errorDomain: nil];
    }
    
    
    AssertEqual(self.db.count, 1);
    for (uint16 i = 0; i < 10; i++) {
        NSError* err = nil;
        AssertEqual([dbs objectAtIndex: i].count, 1);
        Assert([[dbs objectAtIndex: i] close: &err]);
    }
    
    for (uint16 i = 0; i < 10; i++) {
        [[lists objectAtIndex: i] stop];
    }
}

- (void) testListenerWithActiveReplication {
    [self generateDocumentWithID: @"doc-1"];
    
    NSError* err = nil;
    CBLMutableDocument* doc2 = [self createDocument: @"doc-2"];
    [doc2 setString: @"VALUE" forKey: @"key"];
    [otherDB saveDocument: doc2 error: &err];
    
    // passive listener - otherDB
    NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", otherDB.name];
    NSURL* urlToOtherDB = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* listToOtherDB = [self listenTo: urlToOtherDB.host port: 8080 database: otherDB];
    
    // passive listener - self.db
    urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8081/%@", self.db.name];
    NSURL* urlToDB = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* listToDB = [self listenTo: urlToDB.host port: 8081 database: self.db];
    
    CBLURLEndpoint* targetToOtherDB = [[CBLURLEndpoint alloc] initWithURL: urlToOtherDB];
    id config = [self configWithTarget: targetToOtherDB type: kCBLReplicatorTypePush continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    CBLURLEndpoint* targetToDB = [[CBLURLEndpoint alloc] initWithURL: urlToDB];
    CBLReplicatorConfiguration* c = [[CBLReplicatorConfiguration alloc] initWithDatabase: otherDB
                                                                                  target: targetToDB];
    [self run: c errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 2);
    AssertEqual(otherDB.count, 2);
    
    // TODO: check the custom network interface is same!
    
    [listToOtherDB stop];
    [listToDB stop];
}

- (void) testConflictResolution { }

#pragma mark - Authentication

- (void) testBasicAuthentication { }
- (void) testIncorrectBasicAuthentication { }
- (void) testCertificateAuthentication { }
- (void) testIncorrectCertificateAuthentication { }
- (void) testTLSIdentity { }
- (void) testUnAuthorizedAccess { }

#pragma mark - Corner Cases

- (void) testReservedPortAccess { }
- (void) testIncorrectNetworkInterface { }


@end
