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
  if(![_server isStubEmpty]) {
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

- (void)testPipe
{
  [self prepare];
  
  __block int count = 0;
  
  STDeferred *deferred = [STDeferred deferred];
  [[[deferred pipe:^id(id resultObject) {
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
    
    [self notify:kGHUnitWaitStatusSuccess];
    return @"third";
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


@end