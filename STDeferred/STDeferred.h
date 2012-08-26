//
//  STDeferred.h
//  STDeferred
//
//  Created by saiten on 12/08/24.
//  Copyright (c) 2012年 saiten. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
  STDeferredStateUnresolved,
  STDeferredStateResolved,
  STDeferredStateRejected
} STDeferredState;

@class STDeferred;

typedef STDeferred* (^STDeferredBlock)();
typedef void (^STDeferredCallback)(id resultObject);
typedef id (^STDeferredNextCallback)(id resultObject);

@interface STDeferred : NSObject {
  id _myself;
  id _resultObject;
  STDeferredState _state;
  NSMutableArray *_doneList;
  NSMutableArray *_failList;
}

+ (id)deferred;

- (STDeferred*)then:(STDeferredCallback)block;
- (STDeferred*)fail:(STDeferredCallback)block;
- (STDeferred*)pipe:(STDeferredNextCallback)block;
- (STDeferred*)pipe:(STDeferredNextCallback)successBlock fail:(STDeferredNextCallback)failBlock;
+ (STDeferred*)whenWithArray:(NSArray*)deferreds;
+ (STDeferred*)when:deferred, ... NS_REQUIRES_NIL_TERMINATION;
+ (STDeferred*)timeout:(NSTimeInterval)interval;
- (STDeferred*)next:(STDeferredNextCallback)block;

- (BOOL)isResolved;
- (BOOL)isRejected;

- (void)resolve:(id)resultObject;
- (void)reject:(id)resultObject;

@end
