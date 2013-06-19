//
//  STDeferredTest.m
//  STDeferred
//
//  Created by saiten on 12/08/25.
//  Copyright 2012年 saiten. All rights reserved.
//

#import "STDeferred.h"
#import <GHUnitIOS/GHUnit.h>
#import <NLTHTTPStubServer/NLTHTTPStubServer.h>

@interface STDeferredTest : GHAsyncTestCase {
    NLTHTTPStubServer *_server;
}
@end

@implementation STDeferredTest

- (void)setUpClass
{
    [NLTHTTPStubServer globalSettings].port = 12345;
    _server = [NLTHTTPStubServer stubServer];
    [_server startServer];
}

- (void)tearDownClass
{
    [_server stopServer];
    _server = nil;
}

- (void) setUp
{
    [_server clear];
}

- (void) tearDown
{
    if(![_server verify]) {
        GHFail(@"stub not empty");
    }
}

- (void)testThen
{
    __block int count = 1;
    [[[[[STDeferred deferred] then:^(id resultObject) {
        GHAssertEqualStrings(@"success", resultObject, @"");
        GHAssertEquals(1, count++, @"first call");
    }] then:^(id resultObject) {
        GHAssertEqualStrings(@"success", resultObject, @"");
        GHAssertEquals(2, count++, @"second call");
    }] fail:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] resolve:@"success"];
    
    GHAssertEquals(3, count, @"complete");
}

- (void)testThenAfterResolve
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred resolve:@"hoge"];
    
    [[deferred then:^(id resultObject) {
        GHAssertEqualStrings(@"hoge", resultObject, @"");
    }] fail:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }];
}

- (void)testFail
{
    __block int count = 1;
    
    [[[[[STDeferred deferred] then:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"failure", resultObject, @"");
        GHAssertEquals(1, count++, @"first call");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"failure", resultObject, @"");
        GHAssertEquals(2, count++, @"second call");
    }] reject:@"failure"];
    
    GHAssertEquals(3, count, @"failed complete");
}

- (void)testFailAfterReject
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred reject:@"hoge"];
    
    [[deferred then:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"hoge", resultObject, @"");
    }];
}

- (void)testAlways
{
    [[[[[STDeferred deferred] then:^(id resultObject) {
        GHAssertEqualStrings(@"success", resultObject, @"");
    }] fail:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] always:^(id resultObject) {
        GHAssertEqualStrings(@"success", resultObject, @"");
    }] resolve:@"success"];
    
    [[[[[STDeferred deferred] then:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"failure", resultObject, @"");
    }] always:^(id resultObject) {
        GHAssertEqualStrings(@"failure", resultObject, @"");
    }] reject:@"failure"];
}

- (void)testAlwaysAfterResolve
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred resolve:@"hoge"];
    
    [[[deferred then:^(id resultObject) {
        GHAssertEqualStrings(@"hoge", resultObject, @"");
    }] fail:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] always:^(id resultObject) {
        GHAssertEqualStrings(@"hoge", resultObject, @"");
    }];
    
    STDeferred *deferred2 = [STDeferred deferred];
    [deferred2 reject:@"hoge"];
    
    [[[deferred2 then:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"hoge", resultObject, @"");
    }] always:^(id resultObject) {
        GHAssertEqualStrings(@"hoge", resultObject, @"");
    }];
}

- (void)testPipe
{
    [self prepare];
    
    __block int count = 0;
    
    STDeferred *deferred = [STDeferred deferred];
    [[[[[deferred pipe:^id(id resultObject) {
        GHAssertEqualStrings(@"start", resultObject, @"");
        
        STDeferred *deffered = [STDeferred deferred];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            GHAssertEquals(1, count++, @"");
            [deffered resolve:@"first"];
        });
        return deffered;
    }] pipe:^id(id resultObject) {
        GHAssertEqualStrings(@"first", resultObject, @"");
        GHAssertEquals(2, count++, @"");
        return @"second";
    }] pipe:^id(id resultObject) {
        GHAssertEqualStrings(@"second", resultObject, @"");
        GHAssertEquals(3, count++, @"");
        
        return @"third";
    }] then:^(id resultObject) {
        GHAssertEqualStrings(@"third", resultObject, @"");
        [self notify:kGHUnitWaitStatusSuccess];
    }] fail:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }];
    
    [deferred resolve:@"start"];
    
    GHAssertEquals(0, count++, @"");
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:5.0f];
}

- (void)testPipeFailure
{
    [self prepare];
    
    __block int count = 0;
    
    STDeferred *deferred = [STDeferred deferred];
    [[[[deferred pipe:^id(id resultObject) {
        GHAssertEqualStrings(@"start", resultObject, @"");
        
        STDeferred *deffered = [STDeferred deferred];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            GHAssertEquals(1, count++, @"");
            [deffered reject:@"fail"];
        });
        return deffered;
    }] pipe:^id(id resultObject) {
        GHFail(@"呼ばれないこと");
        return @"second";
    }] then:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"fail", resultObject, @"");
        [self notify:kGHUnitWaitStatusSuccess];
    }];
    
    [deferred resolve:@"start"];
    
    GHAssertEquals(0, count++, @"");
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:5.0f];
}

- (void)testNext
{
    [self prepare];
    __block int count = 1;
    
    STDeferred *deferred = [STDeferred deferred];
    
    [[[deferred next:^id(id resultObject) {
        GHAssertEquals(1, count++, @"first call");
        
        return @"first";
    }] next:^id(id resultObject) {
        GHAssertEquals(2, count++, @"second call");
        GHAssertEqualStrings(@"first", resultObject, @"");
        
        return [resultObject stringByAppendingString:@" second"];
    }] next:^id(id resultObject) {
        GHAssertEquals(3, count++, @"last call");
        GHAssertEqualStrings(@"first second", resultObject, @"");
        
        [self notify:kGHUnitWaitStatusSuccess];
        return nil;
    }];
    
    [deferred resolve:nil];
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:3.0f];
}

- (void)testWhen
{
    [self prepare];
    
    
    STDeferred *deferred1 = [STDeferred deferred];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [deferred1 resolve:@"1 sec"];
    });
    
    STDeferred *deferred2 = [STDeferred deferred];
    popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [deferred2 resolve:@"2 sec"];
    });
    
    [[STDeferred when:deferred1, deferred2, nil] then:^(id resultObject) {
        NSArray *results = (NSArray*)resultObject;
        
        GHAssertEquals((NSUInteger)2, [results count], @"");
        GHAssertEqualStrings(@"1 sec", [results objectAtIndex:0], @"");
        GHAssertEqualStrings(@"2 sec", [results objectAtIndex:1], @"");
        
        [self notify:kGHUnitWaitStatusSuccess];
    }];
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0f];
}

- (void)testWhenEndRandom
{
    [self prepare];
    
    STDeferred *deferred1 = [STDeferred deferred];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [deferred1 resolve:@"3 sec"];
    });
    
    STDeferred *deferred2 = [STDeferred deferred];
    popTime = dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [deferred2 resolve:@"1 sec"];
    });
    
    STDeferred *deferred3 = [STDeferred deferred];
    popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [deferred3 resolve:@"2 sec"];
    });
    
    [[STDeferred when:deferred1, deferred2, deferred3, nil] then:^(id resultObject) {
        NSArray *results = (NSArray*)resultObject;
        
        GHAssertEquals((NSUInteger)3, [results count], @"");
        GHAssertEqualStrings(@"3 sec", [results objectAtIndex:0], @"");
        GHAssertEqualStrings(@"1 sec", [results objectAtIndex:1], @"");
        GHAssertEqualStrings(@"2 sec", [results objectAtIndex:2], @"");
        
        [self notify:kGHUnitWaitStatusSuccess];
    }];
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0f];
    
}

- (void)testWhenBlock
{
    [self prepare];
    
    STDeferredBlock block1 = ^{
        STDeferred *deferred = [STDeferred deferred];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0f * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
            [deferred resolve:@"first"];
        });
        return deferred;
    };
    
    STDeferredBlock block2 = ^{
        STDeferred *deferred = [STDeferred deferred];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0f * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
            [deferred resolve:@"second"];
        });
        return deferred;
    };
    
    [[STDeferred when:block1, block2, nil] then:^(id resultObject) {
        GHAssertEquals((NSUInteger)2, [resultObject count], @"");
        GHAssertEqualStrings(@"first", [resultObject objectAtIndex:0], @"");
        GHAssertEqualStrings(@"second", [resultObject objectAtIndex:1], @"");
        [self notify:kGHUnitWaitStatusSuccess];
    }];
    
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:3.0f];
}

- (void)testWhenReturnNil
{
    STDeferred *d1 = [STDeferred deferred];
    [d1 resolve:nil];
    STDeferred *d2 = [STDeferred deferred];
    [d2 resolve:@"d2"];
    [[STDeferred when:d1, d2, nil] then:^(id resultObject) {
        GHAssertEquals((NSUInteger)2, [resultObject count], @"");
        GHAssertEquals([NSNull null], [resultObject objectAtIndex:0], @"");
        GHAssertEqualStrings(@"d2", [resultObject objectAtIndex:1], @"");
    }];
}

- (STDeferred*)request:(NSURLRequest*)request
{
    STDeferred *deferred = [STDeferred deferred];
    
    dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(global_queue, ^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&error];
        if(error) {
            [deferred reject:error];
        } else {
            [deferred resolve:data];
        }
    });
    
    return deferred;
}

- (void)testRequest
{
    [[[[_server stub] forPath:@"/req1"] andJSONResponse:[@"request1" dataUsingEncoding:NSUTF8StringEncoding]] andStatusCode:200];
    [[[[_server stub] forPath:@"/req2"] andJSONResponse:[@"request2" dataUsingEncoding:NSUTF8StringEncoding]] andStatusCode:200];
    [[[[_server stub] forPath:@"/req3"] andJSONResponse:[@"request3" dataUsingEncoding:NSUTF8StringEncoding]] andStatusCode:200];
    
    [self prepare];
    
    NSURLRequest *req1 = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:12345/req1"]];
    NSURLRequest *req2 = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:12345/req2"]];
    NSURLRequest *req3 = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:12345/req3"]];
    
    STDeferred *deferred1 = [self request:req1];
    STDeferred *chain = [deferred1 pipe:^id(id resultObject) {
        NSString *s = [[NSString alloc] initWithData:resultObject encoding:NSUTF8StringEncoding];
        GHAssertEqualStrings(@"request1", s, @"");
        return [self request:req2];
    }];
    
    STDeferred *deferred3 = [self request:req3];
    
    [[STDeferred when:chain, deferred3, nil] then:^(id resultObject) {
        GHAssertEquals((NSUInteger)2, [resultObject count], @"");
        NSString *s1 = [[NSString alloc] initWithData:[resultObject objectAtIndex:0] encoding:NSUTF8StringEncoding];
        NSString *s2 = [[NSString alloc] initWithData:[resultObject objectAtIndex:1] encoding:NSUTF8StringEncoding];
        GHAssertEqualStrings(@"request2", s1, @"");
        GHAssertEqualStrings(@"request3", s2, @"");
        
        [self notify:kGHUnitWaitStatusSuccess];
    }];
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0f];
}

- (void)testThenProperty
{
    __block int count = 1;
    
    STDeferred *deferred = [STDeferred deferred]
    .then(^(id ret) {
        GHAssertEqualStrings(@"success", ret, @"");
        GHAssertEquals(1, count++, @"first call");
    })
    .then(^(id ret) {
        GHAssertEqualStrings(@"success", ret, @"");
        GHAssertEquals(2, count++, @"first call");
    })
    .fail(^(id ret) {
        GHFail(@"呼ばれないこと");
    });
    
    [deferred resolve:@"success"];
    
    GHAssertEquals(3, count, @"complete");
}

- (void)testThenPropertyAfterResolve
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred resolve:@"hoge"];
    
    deferred.then(^(id ret) {
        GHAssertEqualStrings(@"hoge", ret, @"");
    }).fail(^(id ret) {
        GHFail(@"呼ばれないこと");
    });    
}

- (void)testFailProperty
{
    __block int count = 1;
    
    STDeferred *deferred = [STDeferred deferred]
    .then(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .fail(^(id ret) {
        GHAssertEqualStrings(@"fail", ret, @"");
        GHAssertEquals(1, count++, @"first call");
    })
    .fail(^(id ret) {
        GHAssertEqualStrings(@"fail", ret, @"");
        GHAssertEquals(2, count++, @"first call");
    });
    
    [deferred reject:@"fail"];
    
    GHAssertEquals(3, count, @"complete");
}

- (void)testFailPropertyAfterReject
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred reject:@"hoge"];
    
    deferred.then(^(id ret) {
        GHFail(@"呼ばれないこと");
    }).fail(^(id ret) {
        GHAssertEqualStrings(@"hoge", ret, @"");
    });
}

- (void)testAlwaysProperty
{
    STDeferred *deferred = [STDeferred deferred];
    deferred.then(^(id ret) {
        GHAssertEqualStrings(@"success", ret, @"");
    })
    .fail(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .always(^(id ret) {
        GHAssertEqualStrings(@"success", ret, @"");
    });
    
    [deferred resolve:@"success"];

    STDeferred *deferred2 = [STDeferred deferred];
    deferred2.then(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .fail(^(id ret) {
        GHAssertEqualStrings(@"fail", ret, @"");
    })
    .always(^(id ret) {
        GHAssertEqualStrings(@"fail", ret, @"");
    });
    
    [deferred2 reject:@"fail"];
}

- (void)testAlwaysPropertyAfterReject
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred resolve:@"success"];
    
    deferred.then(^(id ret) {
        GHAssertEqualStrings(@"success", ret, @"");
    })
    .fail(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .always(^(id ret) {
        GHAssertEqualStrings(@"success", ret, @"");
    });
    
    STDeferred *deferred2 = [STDeferred deferred];
    [deferred2 reject:@"fail"];
    
    deferred2.then(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .fail(^(id ret) {
        GHAssertEqualStrings(@"fail", ret, @"");
    })
    .always(^(id ret) {
        GHAssertEqualStrings(@"fail", ret, @"");
    });
    
}

- (void)testResolve
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred resolve:@"success"];

    GHAssertTrue(deferred.isResolved, @"trueであること");
    GHAssertFalse(deferred.isRejected, @"falseであること");

    [[deferred then:^(id resultObject) {
        GHAssertEqualStrings(@"success", resultObject, @"");
    }] fail:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }];
}

- (void)testResolveProperty
{
    STDeferred *deferred = [STDeferred deferred];
    deferred.resolve(@"success");

    GHAssertTrue(deferred.isResolved, @"trueであること");
    GHAssertFalse(deferred.isRejected, @"falseであること");
    
    [[deferred then:^(id resultObject) {
        GHAssertEqualStrings(@"success", resultObject, @"");
    }] fail:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }];
}

- (void)testReject
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred reject:@"fail"];
    
    GHAssertFalse(deferred.isResolved, @"falseであること");
    GHAssertTrue(deferred.isRejected, @"trueであること");
    
    [[deferred then:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"fail", resultObject, @"");
    }];
}

- (void)testRejectProperty
{
    STDeferred *deferred = [STDeferred deferred];
    deferred.reject(@"fail");
    
    GHAssertFalse(deferred.isResolved, @"falseであること");
    GHAssertTrue(deferred.isRejected, @"trueであること");
    
    [[deferred then:^(id resultObject) {
        GHFail(@"呼ばれないこと");
    }] fail:^(id resultObject) {
        GHAssertEqualStrings(@"fail", resultObject, @"");
    }];
}

- (void)testPipeProperty
{
    [self prepare];
    
    __block int count = 0;
    
    STDeferred *deferred = [STDeferred deferred];
    
    deferred
    .pipe(^id(id ret) {
        GHAssertEqualStrings(@"start", ret, @"");
        
        STDeferred *deffered = [STDeferred deferred];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            GHAssertEquals(1, count++, @"");
            [deffered resolve:@"first"];
        });
        return deffered;
    }, nil)
    .pipe(^id(id ret) {
        GHAssertEqualStrings(@"first", ret, @"");
        GHAssertEquals(2, count++, @"");
        return @"second";
    }, nil)
    .pipe(^id(id ret) {
        GHAssertEqualStrings(@"second", ret, @"");
        GHAssertEquals(3, count++, @"");
        
        return @"third";
    }, nil)
    .then(^(id ret) {
        GHAssertEqualStrings(@"third", ret, @"");
        [self notify:kGHUnitWaitStatusSuccess];
    })
    .fail(^(id ret) {
        GHFail(@"呼ばれないこと");
    });
    
    [deferred resolve:@"start"];
    
    GHAssertEquals(0, count++, @"");
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:5.0f];
}

- (void)testPipePropertyFailure
{
    [self prepare];
    
    __block int count = 0;
    
    STDeferred *deferred = [STDeferred deferred];
    
    deferred
    .pipe(^id(id ret) {
        GHAssertEqualStrings(@"start", ret, @"");
        
        STDeferred *deffered = [STDeferred deferred];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            GHAssertEquals(1, count++, @"");
            [deffered reject:@"fail"];
        });
        return deffered;
    }, nil)
    .pipe(^id(id ret) {
        GHFail(@"呼ばれないこと");
        return nil;
    }, nil)
    .then(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .fail(^(id ret) {
        GHAssertEqualStrings(@"fail", ret, @"");
        [self notify:kGHUnitWaitStatusSuccess];
    });
    
    [deferred resolve:@"start"];
    
    GHAssertEquals(0, count++, @"");
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:5.0f];
}

- (void)testNextProperty
{
    [self prepare];
    __block int count = 1;
    
    STDeferred *deferred = [STDeferred deferred];
    
    deferred
    .next(^id(id ret) {
        GHAssertEquals(1, count++, @"first call");
        return @"first";
    })
    .next(^id(id ret) {
        GHAssertEquals(2, count++, @"second call");
        GHAssertEqualStrings(@"first", ret, @"");        
        return [ret stringByAppendingString:@" second"];
    })
    .next(^id(id ret) {
        GHAssertEquals(3, count++, @"last call");
        GHAssertEqualStrings(@"first second", ret, @"");
        
        [self notify:kGHUnitWaitStatusSuccess];
        return nil;
    });
    
    [deferred resolve:nil];
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:3.0f];
}

- (void)testNext2
{
    [[[[_server stub] forPath:@"/data.json"] andJSONResponse:[@"{\"name\": \"hogehoge\"}" dataUsingEncoding:NSUTF8StringEncoding]] andStatusCode:200];
    
    [self prepare];
    
    [STDeferred deferred].resolve([NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:12345/data.json"]])
    .next(^id(id request) {
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if(error) {
            @throw [NSException exceptionWithName:@"Request Error" reason:@"Request Error" userInfo:nil];
        }
        return data;
    })
    .next(^id(id responseData) {
        NSError *error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
        if(error) {
            @throw [NSException exceptionWithName:@"Parse Error" reason:@"Parse Error" userInfo:nil];
        }
        return json;
    })
    .then(^(id json) {
        GHAssertEqualStrings(@"hogehoge", [json objectForKey:@"name"], @"");
        [self notify:kGHUnitWaitStatusSuccess];
        NSLog(@"name = %@", [json objectForKey:@"name"]);
    })
    .fail(^(id exception) {
        [self notify:kGHUnitWaitStatusFailure];
        NSLog(@"error = %@", [exception reason]);
    });
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:30.0f];
}

- (void)testRejectAfterResolve
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred resolve:nil];
    GHAssertTrue(deferred.isResolved, @"resolved");
    GHAssertFalse(deferred.isRejected, @"not rejected");
    [deferred reject:nil];
    GHAssertTrue(deferred.isResolved, @"resolved");
    GHAssertFalse(deferred.isRejected, @"not rejected");
}

- (void)testResolveAfterReject
{
    STDeferred *deferred = [STDeferred deferred];
    [deferred reject:nil];
    GHAssertTrue(deferred.isRejected, @"rejected");
    GHAssertFalse(deferred.isResolved, @"not resolved");
    [deferred resolve:nil];
    GHAssertTrue(deferred.isRejected, @"rejected");
    GHAssertFalse(deferred.isResolved, @"not resolved");
}

- (void)testCancel
{
    STDeferred *deferred = [STDeferred deferred]
    .then(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .fail(^(NSError *error) {
        GHAssertEqualStrings(STDeferredErrorDomain, error.domain, @"");
        GHAssertEquals(STDeferredErrorCancel, error.code, @"");
    })
    .canceller(^{
        GHAssertTrue(YES, @"呼ばれること");
    });
    
    [deferred cancel];
}

- (void)testCancelAfterResolve
{
    STDeferred *deferred = [STDeferred deferred]
    .then(^(id ret) {
        GHAssertEqualStrings(@"hoge", ret, @"hoge");
    })
    .fail(^(NSError *error) {
        GHFail(@"呼ばれないこと");
    })
    .canceller(^{
        GHFail(@"呼ばれないこと");
    });

    [deferred resolve:@"hoge"];    
    [deferred cancel];
}

- (void)testCancelAfterReject
{
    STDeferred *deferred = [STDeferred deferred]
    .then(^(id ret) {
        GHFail(@"呼ばれないこと");
    })
    .fail(^(id ret) {
        GHAssertEqualStrings(@"hoge", ret, @"hoge");
    })
    .canceller(^{
        GHFail(@"呼ばれないこと");
    });
    
    [deferred reject:@"hoge"];
    [deferred cancel];
}

- (void)testCancelWhen
{
    __block int sequenceCount = 0;
    
    STDeferred *d1 = [STDeferred deferred]
    .fail(^(NSError *error) {
        GHAssertEqualStrings(STDeferredErrorDomain, error.domain, @"");
        GHAssertEquals(STDeferredErrorCancel, error.code, @"");
    })
    .canceller(^{
        GHAssertEquals(1, sequenceCount++, @"1");
    });
    
    STDeferred *d2 = [STDeferred deferred]
    .fail(^(NSError *error) {
        GHAssertEqualStrings(STDeferredErrorDomain, error.domain, @"");
        GHAssertEquals(STDeferredErrorCancel, error.code, @"");
    })
    .canceller(^{
        GHAssertEquals(2, sequenceCount++, @"2");
    });
    
    STDeferred *when = [STDeferred when:d1, d2, nil]
    .then(^(id ret) {
        GHFail(@"呼ばれない");
    })
    .fail(^(NSError *error) {
        GHAssertEqualStrings(STDeferredErrorDomain, error.domain, @"");
        GHAssertEquals(STDeferredErrorCancel, error.code, @"");
        GHAssertEquals(3, sequenceCount++, @"3");
    });

    GHAssertEquals(0, sequenceCount++, @"0");
    
    [when cancel];
    
    GHAssertEquals(4, sequenceCount, @"4");
}

- (void)testCancelPipe
{
    __block int sequenceCount = 0;

    STDeferred *d1 = [STDeferred deferred];
    d1.canceller(^{
        GHAssertEquals(1, sequenceCount++, @"1");
    });
    
    STDeferred *d2 = d1.pipe(nil, nil);
    STDeferred *d3 = d2.pipe(nil, nil);
    d3.fail(^(id ret) {
        GHAssertEquals(2, sequenceCount++, @"2");
    });
    
    GHAssertEquals(0, sequenceCount++, @"0");
    [d3 cancel];
    
    sequenceCount = 0;

}

- (void)testCancelPipeHalfway
{
    __block int sequenceCount = 0;
    
    STDeferred *pipeDeferred = [STDeferred deferred].resolve(nil)
    .pipe(^id(id ret) {
        STDeferred *d = [STDeferred deferred]
        .then(^(id ret) {
            GHFail(@"呼ばれない");
        })
        .fail(^(id ret) {
            GHAssertEquals(2, sequenceCount++, @"2");
        })
        .canceller(^() {
            GHAssertEquals(1, sequenceCount++, @"1");
        });
        return d;
    }, nil)
    .pipe(^id(id ret) {
        GHFail(@"呼ばない");
        return nil;
    }, nil);
    
    GHAssertEquals(0, sequenceCount++, @"0");
    
    pipeDeferred
    .then(^(id ret) {
        GHFail(@"呼ばれない");
    })
    .fail(^(id ret) {
        GHAssertEquals(3, sequenceCount++, @"3");
    });
    
    [pipeDeferred cancel];
}

- (void)testCancelPipeLast
{
    __block int sequenceCount = 0;
    
    STDeferred *pipeDeferred = [STDeferred deferred].resolve(nil)
    .pipe(^id(id ret) {
        return [STDeferred deferred].resolve(nil).canceller(^{
            GHFail(@"呼ばれない");
        });
    }, nil)
    .pipe(^id(id ret) {
        return [STDeferred deferred].resolve(nil).canceller(^{
            GHFail(@"呼ばれない");
        });
    }, nil)
    .pipe(^id(id ret) {
        STDeferred *d = [STDeferred deferred]
        .then(^(id ret) {
            GHFail(@"呼ばれない");
        })
        .fail(^(id ret) {
            GHAssertEquals(2, sequenceCount++, @"2");
        })
        .canceller(^() {
            GHAssertEquals(1, sequenceCount++, @"1");
        });
        return d;
    }, nil);
    
    GHAssertEquals(0, sequenceCount++, @"0");
    
    pipeDeferred
    .then(^(id ret) {
        GHFail(@"呼ばれない");
    })
    .fail(^(id ret) {
        GHAssertEquals(3, sequenceCount++, @"3");
    });
    
    [pipeDeferred cancel];    
}

- (void)testPipeBlocksNil
{
    [STDeferred deferred].resolve(@"foo")
    .pipe(nil, nil)
    .then(^(id ret) {
        GHAssertEqualStrings(@"foo", ret, @"foo");
    })
    .fail(^(id ret) {
        GHFail(@"呼ばれない");
    });
    
    [STDeferred deferred].reject(@"foo")
    .pipe(nil, nil)
    .then(^(id ret) {
        GHFail(@"呼ばれない");
    })
    .fail(^(id ret) {
        GHAssertEqualStrings(@"foo", ret, @"foo");
    });
    
}

@end