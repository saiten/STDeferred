//
//  STDeferredTest.m
//  STDeferred
//
//  Created by saiten on 12/08/25.
//  Copyright 2012年 saiten. All rights reserved.
//

#import "STDeferred.h"
#import <GHUnitIOS/GHUnit.h>
 
@interface STDeferredTest : GHAsyncTestCase { }
@end
 
@implementation STDeferredTest

- (void) setUp
{
}

- (void) tearDown
{
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

@end