//
//  STDeferred.m
//  STDeferred
//
//  Created by saiten on 12/08/24.
//  Copyright (c) 2012年 saiten. All rights reserved.
//

#import "STDeferred.h"

@implementation STDeferred

- (id)init
{
  self = [super init];
  if(self) {
    _myself = self;
    _resultObject = nil;
    _state = STDeferredStateUnresolved;
    _doneList = [NSMutableArray array];
    _failList = [NSMutableArray array];
  }
  return self;
}

+ (id)deferred
{
  return [[self alloc] init];
}

+ (STDeferred *)whenWithArray:(NSArray*)deferreds
{
  STDeferred *deferred = [STDeferred deferred];

  __block NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:deferreds.count];
  
  STDeferredCallback failure = ^(id resultObject) {
    [deferred reject:resultObject];
  };

  for(int i = 0; i < deferreds.count; i++) {
    __block int index = i;
    STDeferred *argDeferred = [deferreds objectAtIndex:index];
    STDeferredCallback success = ^(id resultObject) {
      [results setObject:resultObject forKey:[NSNumber numberWithInt:index]];
      if(results.count == deferreds.count) {
        NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:deferreds.count];
        for(int j = 0; j < deferreds.count ; j++) {
          [resultArray addObject:[results objectForKey:[NSNumber numberWithInt:j]]];
        }
        [deferred resolve:resultArray];
      }
    };
    
    if([argDeferred isKindOfClass:[STDeferred class]]) {
      [[argDeferred then:success] fail:failure];
    } else if([argDeferred isKindOfClass:NSClassFromString(@"NSBlock")]) {
      id (^block)() = (id (^)())argDeferred;
      id resultObject = block();
      if([resultObject isKindOfClass:[STDeferred class]]) {
        [[(STDeferred*)resultObject then:success] fail:failure];
      } else {
        [[[STDeferred deferred] then:success] resolve:block()];
      }
    } else {
      [[[STDeferred deferred] then:success] resolve:argDeferred];
    }
  }
  
  return deferred;
}

+ (STDeferred *)when:(id)firstArg, ...
{
  va_list args;
  va_start(args, firstArg);
  
  NSMutableArray *deferreds = [NSMutableArray array];
  for(STDeferred *deferred = firstArg; deferred != nil; deferred = va_arg(args, STDeferred*)) {
    [deferreds addObject:deferred];
  }
  va_end(args);
  
  return [self whenWithArray:deferreds];
}

+ (STDeferred*)timeout:(NSTimeInterval)interval
{
  STDeferred *deferred = [STDeferred deferred];
  
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC);
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    [deferred resolve:nil];
  });
  return deferred;
}


- (BOOL)isResolved
{
  return _state == STDeferredStateResolved;
}

- (BOOL)isRejected
{
  return _state == STDeferredStateRejected;
}

- (void)resolve:(id)resultObject
{
  _state = STDeferredStateResolved;
  [self _fire:resultObject];
}

- (void)reject:(id)resultObject
{
  _state = STDeferredStateUnresolved;
  [self _fire:resultObject];
}

- (STDeferred *)then:(STDeferredCallback)block
{
  [_doneList addObject:[block copy]];
  if(_state != STDeferredStateUnresolved) {
    [self _fire:nil];
  }
  return self;
}

- (STDeferred *)fail:(STDeferredCallback)block
{
  [_failList addObject:[block copy]];
  if(_state != STDeferredStateUnresolved) {
    [self _fire:nil];
  }
  return self;
}

- (STDeferred *)pipe:(STDeferredNextCallback)block
{
  STDeferred *deferred = [STDeferred deferred];
  
  [self then:^(id resultObject) {
    id ret = block(resultObject);
    if([ret isKindOfClass:[STDeferred class]]) {
      [(STDeferred*)ret then:^(id newResultObject) {
        [deferred resolve:newResultObject];
      }];
    } else {
      [deferred resolve:ret];
    }
  }];
  
  return deferred;
}

- (STDeferred *)next:(STDeferredNextCallback)block
{
  return [self pipe:^id(id resultObject) {
    STDeferred *deferred = [STDeferred deferred];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [deferred resolve:block(resultObject)];
    });
    return deferred;
  }];
}

- (void)_fire:(id)resultObject
{
  NSArray *list = self.isResolved ? _doneList : _failList;
  for(STDeferredCallback block in list) {
    if(block) {
      @try {
        block(resultObject);
      }
      @catch (NSException *exception) {
        _state = STDeferredStateRejected;
      }
    }
  }
  _myself = nil;
}

@end
