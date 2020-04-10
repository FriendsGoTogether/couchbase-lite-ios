//
//  URLEndpointListenerTest.m
//  CBL ObjC Tests
//
//  Created by Jayahari Vavachan on 3/3/20.
//  Copyright © 2020 Couchbase. All rights reserved.
//

#import "ReplicatorTest.h"
#import "CBLDatabase+Internal.h"
#import "MYAnonymousIdentity.h"

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
    
    return [self listen: config];
}

- (CBLURLEndpointListener*) listen: (CBLURLEndpointListenerConfiguration*)config {
    CBLURLEndpointListener* listener = [[CBLURLEndpointListener alloc] initWithConfig: config];
    
    NSError* err = nil;
    [listener startWithError: &err];
    return listener;
}

#pragma mark - Basic Tests

- (void) testCustomPort {
    CBLDatabase.log.console.level = kCBLLogLevelInfo;
    NSString* urlString = [NSString stringWithFormat: @"ws://localhost:5666/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listenTo: nil port: 5666 database: self.otherDB];

    [self generateDocumentWithID: @"doc-1"];
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    id config = [self configWithTarget: target type: kCBLReplicatorTypePush continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual(self.otherDB.count, 1);
    
    // TODO: get and verify the ports are same!
    
    [list stop];
}

- (void) testDefaultPort {
    CBLDatabase.log.console.level = kCBLLogLevelInfo;
    NSString* urlString = [NSString stringWithFormat: @"ws://localhost:4984/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listenTo: nil port: 0 database: self.otherDB];

    [self generateDocumentWithID: @"doc-1"];
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    id config = [self configWithTarget: target type: kCBLReplicatorTypePush continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual(self.otherDB.count, 1);
    
    // TODO: get and verify the ports are same!
    
    [list stop];
}

- (void) testReadOnlyListener {
    CBLDatabase.log.console.level = kCBLLogLevelInfo;
    NSString* urlString = [NSString stringWithFormat: @"ws://localhost:4984/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListenerConfiguration* config;
    config = [[CBLURLEndpointListenerConfiguration alloc] initWithDatabase: self.otherDB port: 4984
                                                          networkInterface: nil
                                                                  identity: nil];
    config.readOnly = YES;
    CBLURLEndpointListener* list = [self listen: config];

    [self generateDocumentWithID: @"doc-1"];
    CBLMutableDocument* doc = [self createDocument: @"doc-2"];
    [doc setString: @"avl" forKey:@"key1"];
    NSError* error;
    [self.otherDB saveDocument: doc error: &error];
    
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    id rConfig = [self configWithTarget: target type: kCBLReplicatorTypePushAndPull continuous: NO];
    [self run: rConfig errorCode: CBLErrorRemoteError errorDomain: CBLErrorDomain];
    
    AssertEqual(self.db.count, 2);
    AssertEqual(self.otherDB.count, 1);
    
    // TODO: get and verify the ports are same!
    
    [list stop];
}


- (void) testCustomNetworkInterface {
    NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listenTo: url.host port: 8080 database: self.otherDB];

    [self generateDocumentWithID: @"doc-1"];
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    id config = [self configWithTarget: target type: kCBLReplicatorTypePush continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual(self.otherDB.count, 1);
    
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
    [self.otherDB saveDocument: doc2 error: &err];
    
    // passive listener - otherDB
    NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", self.otherDB.name];
    NSURL* urlToOtherDB = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* listToOtherDB = [self listenTo: urlToOtherDB.host port: 8080 database: self.otherDB];
    
    // passive listener - self.db
    urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8081/%@", self.db.name];
    NSURL* urlToDB = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* listToDB = [self listenTo: urlToDB.host port: 8081 database: self.db];
    
    CBLURLEndpoint* targetToOtherDB = [[CBLURLEndpoint alloc] initWithURL: urlToOtherDB];
    id config = [self configWithTarget: targetToOtherDB type: kCBLReplicatorTypePush continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    CBLURLEndpoint* targetToDB = [[CBLURLEndpoint alloc] initWithURL: urlToDB];
    CBLReplicatorConfiguration* c = [[CBLReplicatorConfiguration alloc] initWithDatabase: self.otherDB
                                                                                  target: targetToDB];
    [self run: c errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 2);
    AssertEqual(self.otherDB.count, 2);
    
    // TODO: check the custom network interface is same!
    
    [listToOtherDB stop];
    [listToDB stop];
}

- (void) testConflictResolution {
    NSError* err = nil;
    CBLMutableDocument* doc1 = [self createDocument: @"doc-1"];
    [doc1 setString: @"add" forKey: @"action"];
    Assert([self.db saveDocument: doc1 error: &err]);
    AssertNil(err);
    
    doc1 = [self createDocument: @"doc-1"];
    [doc1 setString: @"add" forKey: @"action"];
    Assert([self.otherDB saveDocument: doc1 error: &err]);
    AssertNil(err);
    
    doc1 = [[self.otherDB documentWithID: @"doc-1"] toMutable];
    [doc1 setString: @"addition" forKey: @"action"];
    Assert([self.otherDB saveDocument: doc1 error: &err]);
    AssertNil(err);
    AssertEqual([self.otherDB documentWithID: @"doc-1"].sequence, 2);
    
    NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listenTo: url.host port: 8080 database: self.otherDB];

    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    id config = [self configWithTarget: target type: kCBLReplicatorTypePushAndPull continuous: NO];
    [self run: config errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual([self.db documentWithID: @"doc-1"].sequence, 2);
    
    AssertEqual(self.otherDB.count, 1);
    AssertEqual([self.otherDB documentWithID: @"doc-1"].sequence, 2);
    
    [list stop];
}

- (void) _testListenerWithMultiplePeers {
    CBLDatabase.log.console.level = kCBLLogLevelInfo;
    CBLURLEndpointListener* list = [self listenTo: @"127.0.0.1" port: 8080 database: self.db];
    
    // DB - 1
    NSError* error = nil;
    CBLDatabase* db = [[CBLDatabase alloc] initWithName: @"dbName-1" error: &error];
    AssertNil(error);
    
    CBLMutableDocument* doc = [CBLMutableDocument documentWithID: @"doc-1"];
    [doc setString: @"data1" forKey: @"key"];
    [db saveDocument: doc error: &error];
    AssertNil(error);
    
    NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", self.db.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpoint* t = [[CBLURLEndpoint alloc] initWithURL: url];
    
    CBLReplicatorConfiguration* config = [[CBLReplicatorConfiguration alloc] initWithDatabase: db
                                                                                       target: t];
    
    XCTestExpectation* ex1 = [self expectationWithDescription: @"ex1"];
    CBLReplicator* repl1 = [[CBLReplicator alloc] initWithConfig: config];
    id token1 = [repl1 addChangeListener: ^(CBLReplicatorChange * change) {
        if (change.status.activity == kCBLReplicatorStopped) {
            [ex1 fulfill];
        }
    }];
    
    // DB - 2
    db = [[CBLDatabase alloc] initWithName: @"dbName-1" error: &error];
    AssertNil(error);
    doc = [CBLMutableDocument documentWithID: @"doc-1"];
    [doc setString: @"data1" forKey: @"key"];
    [db saveDocument: doc error: &error];
    AssertNil(error);
    
    urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", self.db.name];
    url = [[NSURL alloc] initWithString: urlString];
    t = [[CBLURLEndpoint alloc] initWithURL: url];
    
    config = [[CBLReplicatorConfiguration alloc] initWithDatabase: db target: t];
    
    XCTestExpectation* ex2 = [self expectationWithDescription: @"ex2"];
    CBLReplicator* repl2 = [[CBLReplicator alloc] initWithConfig: config];
    id token2 = [repl2 addChangeListener: ^(CBLReplicatorChange * change) {
        if (change.status.activity == kCBLReplicatorStopped) {
            [ex2 fulfill];
        }
    }];
    
    [repl1 start];
    [repl2 start];
    
    [self waitForExpectations: @[ex1, ex2] timeout: 5.0];
    [repl1 removeChangeListenerWithToken: token1];
    [repl2 removeChangeListenerWithToken: token2];
    
    [list stop];
}


#pragma mark - TLS Identity
- (void) _testAuthorizationWithTLSIdentity {
    NSError* error = nil;
    CBLURLEndpointListenerConfiguration * config;
    CBLTLSIdentity* tls = [CBLTLSIdentity createServerIdentity: @{} expiration: nil error: &error];
    
    config = [[CBLURLEndpointListenerConfiguration alloc] initWithDatabase: self.otherDB
                                                                      port: 8080 identity: tls];
    
    NSString* urlString = [NSString stringWithFormat: @"wss://127.0.0.1:8080/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listen: config];
    
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    CBLReplicatorConfiguration* replConf = [self configWithTarget: target
                                                             type: kCBLReplicatorTypePushAndPull
                                                       continuous: NO];
    SecCertificateRef cert = NULL;
    OSStatus status = SecIdentityCopyCertificate(tls.identity, &cert);
    Assert(status == errSecSuccess);
    Assert(cert != NULL);
    replConf.pinnedServerCertificate = cert;
    [self run: replConf errorCode: 0 errorDomain: nil];
    
    [list stop];
}

#pragma mark - Authentication
- (void) testBasicAuthentication {
    NSString* urlString = [NSString stringWithFormat: @"ws://127.0.0.1:8080/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLURLEndpointListener* list = [self listenTo: url.host port: 8080 database: self.otherDB];
    
    [self generateDocumentWithID: @"doc-1"];
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    CBLReplicatorConfiguration* config = [self configWithTarget: target
                                                           type: kCBLReplicatorTypePush
                                                     continuous: NO];
    config.authenticator = [[CBLBasicAuthenticator alloc] initWithUsername: @"username" password: @"password"];
    
    [self run: config errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual(self.otherDB.count, 1);
    
    // TODO: check the custom network interface is same!
    
    [list stop];
}

- (void) _testCertificateAuthentication {
    CBLDatabase.log.console.level = kCBLLogLevelInfo;
    NSError* error = nil;
    SecIdentityRef ref = MYGetOrCreateAnonymousIdentity(@"MyCertIdentity",
                                                        kMYAnonymousIdentityDefaultExpirationInterval,
                                                        &error);
    NSString* urlString = [NSString stringWithFormat: @"wss://127.0.0.1:8080/%@", self.otherDB.name];
    NSURL* url = [[NSURL alloc] initWithString: urlString];
    CBLTLSIdentity* tls = [[CBLTLSIdentity alloc] initWithIdentity: ref caCerts: @[]];
    
    id config = [[CBLURLEndpointListenerConfiguration alloc] initWithDatabase: self.otherDB
                                                                         port: 8080 identity: tls];
    CBLURLEndpointListener* list = [self listen: config];
    
    
    [self generateDocumentWithID: @"doc-1"];
    CBLURLEndpoint* target = [[CBLURLEndpoint alloc] initWithURL: url];
    CBLReplicatorConfiguration* rConfig = [[CBLReplicatorConfiguration alloc] initWithDatabase: self.db
                                                                                        target: target];
    
    CBLClientCertAuthenticator* certAuth = [[CBLClientCertAuthenticator alloc] initWithIdentityID: @"MyCertIdentity"];
    rConfig.authenticator = certAuth;
    [self run: rConfig errorCode: 0 errorDomain: nil];
    
    AssertEqual(self.db.count, 1);
    AssertEqual(self.otherDB.count, 1);
    
    // TODO: check the custom network interface is same!
    
    [list stop];
}

- (void) testIncorrectBasicAuthentication { }
- (void) testIncorrectCertificateAuthentication { }

#pragma mark - Corner Cases

- (void) testReservedPortAccess { }             // lite core ??
- (void) testIncorrectNetworkInterface { }      // lite core ??

#pragma mark -  p2
- (void) testUnAuthorizedTLSIdentity { }
- (void) testPassServerCertForClientAccess { }
- (void) testPassClientCertForServerAccess { }

- (void) testCreateBasicServerTLSIdentity {
    // pass empty attributes and empty expiry
}
- (void) testCreateServerTLSIdentityWithExpiration {
    // With Specified expiry and check whether invalid after specified date
}
- (void) testCreateServerTLSIdentityWithAllAttributes { }
- (void) testCreateServerTLSIdentityWithInvalidAttributes { }
- (void) testCreateClientTLSIdentityWithAllAttributes {
    // only basic test for client, since server is similar with client
}

- (void) testStoreServerTLSIdentity { }
- (void) testDeleteServerTLSIdentity { }
- (void) testGetServerTLSIdentity { }


#pragma mark - LiteCore tests
// - invalid TLSIdentity name components.
// - reserved and invalid port access
// - invalid network interface

@end
