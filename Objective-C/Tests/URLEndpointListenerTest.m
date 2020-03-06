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

- (void) testStartListenerPort {
    CBLURLEndpointListenerConfiguration* config = [[CBLURLEndpointListenerConfiguration alloc] initWithDatabase: self.db
                                                                                                           port: 0
                                                                                                       identity: nil];
    CBLURLEndpointListener* listener = [[CBLURLEndpointListener alloc] initWithConfig: config];
    
    NSError* err = nil;
    [listener startWithError: &err];
    [NSThread sleepForTimeInterval: 1.0];
    
    [listener stop];
}

- (void) testStartListenerPortAndNetworkInterface {
    CBLURLEndpointListenerConfiguration* config = [[CBLURLEndpointListenerConfiguration alloc] initWithDatabase: self.db
                                                                                                           port: 0
                                                                                               networkInterface: @"localhost"
                                                                                                       identity: nil];
    CBLURLEndpointListener* listener = [[CBLURLEndpointListener alloc] initWithConfig: config];
    
    NSError* err = nil;
    [listener startWithError: &err];
    [NSThread sleepForTimeInterval: 1.0];
    
    [listener stop];
}


@end
