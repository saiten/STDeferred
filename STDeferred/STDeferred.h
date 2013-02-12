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
typedef void (^STDeferredCancelBlock)();

typedef enum _STDeferredErrorType {
    STDeferredErrorException,
    STDeferredErrorCancel
} STDeferredErrorType;

extern NSString * const STDeferredErrorDomain;

@interface STDeferred : NSObject {
    id _resultObject;
    STDeferredState _state;
    NSMutableArray *_doneList;
    NSMutableArray *_failList;
    NSMutableArray *_alwaysList;
    STDeferredCancelBlock _canceller;
}

+ (instancetype)deferred;

@property (readonly) STDeferred *(^then)(STDeferredCallback block);
@property (readonly) STDeferred *(^fail)(STDeferredCallback block);
@property (readonly) STDeferred *(^always)(STDeferredCallback block);
@property (readonly) STDeferred *(^pipe)(STDeferredNextCallback successBlock, STDeferredNextCallback failBlock);
@property (readonly) STDeferred *(^next)(STDeferredNextCallback block);
@property (readonly) STDeferred *(^resolve)(id resultObject);
@property (readonly) STDeferred *(^reject)(id resultObject);
@property (readonly) STDeferred *(^canceller)(STDeferredCancelBlock block);

- (STDeferred*)then:(STDeferredCallback)block;
- (STDeferred*)fail:(STDeferredCallback)block;
- (STDeferred*)always:(STDeferredCallback)block;
- (STDeferred*)pipe:(STDeferredNextCallback)block;
- (STDeferred*)pipe:(STDeferredNextCallback)successBlock fail:(STDeferredNextCallback)failBlock;
+ (STDeferred*)whenWithArray:(NSArray*)deferreds;
+ (STDeferred*)when:deferred, ... NS_REQUIRES_NIL_TERMINATION;
+ (STDeferred*)timeout:(NSTimeInterval)interval;
- (STDeferred*)next:(STDeferredNextCallback)block;
- (STDeferred*)canceller:(STDeferredCancelBlock)block;

- (BOOL)isResolved;
- (BOOL)isRejected;

- (void)resolve:(id)resultObject;
- (void)reject:(id)resultObject;

- (void)cancel;

@end
