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
    _resultObject = nil;
    _state = STDeferredStateUnresolved;
    _doneList = [NSMutableArray array];
    _failList = [NSMutableArray array];
  }
  NSLog(@"init -> %d", ++count);
  return self;
}

- (void)dealloc
{
  _resultObject = nil;
  _doneList = nil;
  _failList = nil;
}

+ (id)deferred
{
  return [[self alloc] init];
}

+ (STDeferred *)whenWithArray:(NSArray*)deferreds
{
  STDeferred *deferred = [STDeferred deferred];
  int deferredCount = deferreds.count;

  __block NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:deferredCount];
  
  STDeferredCallback failureCallback = ^(id resultObject) {
    [deferred reject:resultObject];
  };

  for(int i = 0; i < deferredCount; i++) {
    __block int index = i;
    STDeferred *argDeferred = [deferreds objectAtIndex:index];
    
    STDeferredCallback successCallback = ^(id resultObject) {
      [results setObject:resultObject forKey:[NSNumber numberWithInt:index]];
      
      if(results.count == deferredCount) {
        NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:deferredCount];
        for(int j = 0; j < deferredCount ; j++) {
          [resultArray addObject:[results objectForKey:[NSNumber numberWithInt:j]]];
        }
        [deferred resolve:resultArray];
      }
    };
    
    if([argDeferred isKindOfClass:[STDeferred class]]) {
      [[argDeferred then:successCallback] fail:failureCallback];
    } else if([argDeferred isKindOfClass:NSClassFromString(@"NSBlock")]) {
      id (^block)() = (id (^)())argDeferred;
      id resultObject = block();
      if([resultObject isKindOfClass:[STDeferred class]]) {
        [[(STDeferred*)resultObject then:successCallback] fail:failureCallback];
      } else {
        [[[STDeferred deferred] then:successCallback] resolve:block()];
      }
    } else {
      [[[STDeferred deferred] then:successCallback] resolve:argDeferred];
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
  if(_state == STDeferredStateResolved) {
    block(_resultObject);
  }
  return self;
}

- (STDeferred *)fail:(STDeferredCallback)block
{
  [_failList addObject:[block copy]];
  if(_state == STDeferredStateRejected) {
    block(_resultObject);
  }
  return self;
}

- (STDeferred *)pipe:(STDeferredNextCallback)successBlock fail:(STDeferredNextCallback)failBlock
{
  STDeferred *deferred = [STDeferred deferred];
  if(successBlock) {
    [self then:^(id resultObject) {
      id ret = successBlock(resultObject);
      if([ret isKindOfClass:[STDeferred class]]) {
        [[(STDeferred*)ret then:^(id newResultObject) {
          [deferred resolve:newResultObject];
        }] fail:^(id newResultObject) {
          [deferred reject:newResultObject];
        }];
      } else {
        [deferred resolve:ret];
      }
    }];
  }
  if(failBlock) {
    [self fail:^(id resultObject) {
      id ret = failBlock(resultObject);
      if([ret isKindOfClass:[STDeferred class]]) {
        [[(STDeferred*)ret then:^(id newResultObject) {
          [deferred resolve:newResultObject];
        }] fail:^(id newResultObject) {
          [deferred reject:newResultObject];
        }];
      } else {
        [deferred reject:ret];
      }
    }];
  }
  return deferred;
}

- (STDeferred *)pipe:(STDeferredNextCallback)block
{
  return [self pipe:block fail:^id(id resultObject) {
    return resultObject;
  }];
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
  _resultObject = resultObject;
  
  NSArray *list = self.isResolved ? _doneList : _failList;
  for(STDeferredCallback block in list) {
    if(block) {
      @try {
        block(_resultObject);
      }
      @catch (NSException *exception) {
        _state = STDeferredStateRejected;
      }
    }
  }
}

@end
