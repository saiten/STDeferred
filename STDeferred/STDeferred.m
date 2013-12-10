//
//  STDeferred.m
//  STDeferred
//
//  Created by saiten on 12/08/24.
//  Copyright (c) 2012年 saiten. All rights reserved.
//

#import "STDeferred.h"

NSString * const STDeferredErrorDomain = @"STDeferredErrorDomain";

@implementation STDeferred

- (id)init
{
    self = [super init];
    if(self) {
        _resultObject = nil;
        _state = STDeferredStateUnresolved;
        _doneList = [NSMutableArray array];
        _failList = [NSMutableArray array];
        _alwaysList = [NSMutableArray array];
        _canceller = nil;
    }
    return self;
}

- (void)dealloc
{
    _resultObject = nil;
    _doneList = nil;
    _failList = nil;
    _alwaysList = nil;
    _canceller = nil;
}

+ (instancetype)deferred
{
    return [[self alloc] init];
}

+ (STDeferred *)whenWithArrayInternal:(NSArray *)deferreds
{
    STDeferred *deferred = [STDeferred deferred];
    
    int deferredsCount = deferreds.count;
    __block int resolveCount = 0;
    
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:deferredsCount];
    
    for(int i = 0; i < deferredsCount; i++) {
        int index = i;
        [results insertObject:[NSNull null] atIndex:index];
        
        STDeferred *childDeferred = [deferreds objectAtIndex:index];
        
        childDeferred
        .then(^(id resultObject) {
            if(resultObject) {
                [results replaceObjectAtIndex:index withObject:resultObject];
            }
            resolveCount++;
            if(resolveCount >= deferredsCount) {
                [deferred resolve:results];
            }
        })
        .fail(^(NSError *resultObject){
            if(!([resultObject.domain isEqualToString:STDeferredErrorDomain] && resultObject.code == STDeferredErrorCancel)) {
                [deferred reject:resultObject];
            }
        });
    }
    
    __weak NSArray *weakDeferreds = deferreds;
    deferred.canceller(^{
        for(STDeferred *deferred in weakDeferreds) {
            [deferred cancel];
        }
    });
    
    return deferred;
}

+ (STDeferred *)whenWithArray:(NSArray *)deferreds
{
    NSMutableArray *newDeferreds = [NSMutableArray arrayWithCapacity:deferreds.count];
    
    for(id obj in deferreds) {
        if([obj isKindOfClass:[STDeferred class]]) {
            [newDeferreds addObject:obj];
        }
        else if([obj isKindOfClass:NSClassFromString(@"NSBlock")]) {
            id (^block)() = (id (^)())obj;
            id resultObject = block();
            if([resultObject isKindOfClass:[STDeferred class]]) {
                [newDeferreds addObject:resultObject];
            } else {
                STDeferred *tmpDeferred = [STDeferred deferred].resolve(resultObject);
                [newDeferreds addObject:tmpDeferred];
            }
        }
        else {
            STDeferred *tmpDeferred = [STDeferred deferred].resolve(obj);
            [newDeferreds addObject:tmpDeferred];
        }
    }
    
    return [self whenWithArrayInternal:newDeferreds];
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
    if(_state == STDeferredStateUnresolved) {
        _state = STDeferredStateResolved;
        [self _fire:resultObject];
    }
}

- (void)reject:(id)resultObject
{
    if(_state == STDeferredStateUnresolved) {
        _state = STDeferredStateRejected;
        [self _fire:resultObject];
    }
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

- (STDeferred *)always:(STDeferredCallback)block
{
    [_alwaysList addObject:[block copy]];
    if(_state != STDeferredStateUnresolved) {
        block(_resultObject);
    }
    return self;
}

- (STDeferred *)pipe:(STDeferredNextCallback)successBlock fail:(STDeferredNextCallback)failBlock
{
    STDeferred *deferred = [STDeferred deferred];

    __weak typeof(id) weakSelf = self;
    deferred.canceller(^{
        [weakSelf cancel];
    });
    
    if(!successBlock) {
        successBlock = ^id(id resultObject) {
            return resultObject;
        };
    }
    [self then:^(id resultObject) {
        id ret = successBlock(resultObject);
        if([ret isKindOfClass:[STDeferred class]]) {
            __weak STDeferred *resultDeferred = ret;
            [[resultDeferred then:^(id newResultObject) {
                [deferred resolve:newResultObject];
            }] fail:^(id newResultObject) {
                [deferred reject:newResultObject];
            }];
            deferred.canceller(^{
                [resultDeferred cancel];
                [weakSelf cancel];
            });
        } else {
            [deferred resolve:ret];
        }
    }];
    
    if(!failBlock) {
        failBlock = ^id(id resultObject) {
            return resultObject;
        };
    }
    [self fail:^(id resultObject) {
        id ret = failBlock(resultObject);
        if([ret isKindOfClass:[STDeferred class]]) {
            __weak STDeferred *resultDeferred = ret;
            [[resultDeferred then:^(id newResultObject) {
                [deferred resolve:newResultObject];
            }] fail:^(id newResultObject) {
                [deferred reject:newResultObject];
            }];
            deferred.canceller(^{
                [resultDeferred cancel];
                [weakSelf cancel];
            });
        } else {
            [deferred reject:ret];
        }
    }];

    return deferred;
}

- (STDeferred *)pipe:(STDeferredNextCallback)block
{
    return [self pipe:block fail:nil];
}

- (STDeferred *)next:(STDeferredNextCallback)block
{
    return [self pipe:^id(id resultObject) {
        STDeferred *deferred = [STDeferred deferred];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @try {
                id ret = block(resultObject);
                [deferred resolve:ret];
            }
            @catch (NSException *exception) {
                [deferred reject:exception];
            }
        });
        return deferred;
    }];
}

- (void)_fire:(id)resultObject
{
    _resultObject = resultObject;
    
    NSArray *list = self.isResolved ? _doneList : _failList;
    for(STDeferredCallback block in [list arrayByAddingObjectsFromArray:_alwaysList]) {
        if(block) {
            block(_resultObject);
        }
    }
}

- (STDeferred *(^)(STDeferredCallback))then
{
    return ^STDeferred *(STDeferredCallback callback) {
        return [self then:callback];
    };
}

- (STDeferred *(^)(STDeferredCallback))fail
{
    return ^STDeferred *(STDeferredCallback callback) {
        return [self fail:callback];
    };
}

- (STDeferred *(^)(STDeferredCallback))always
{
    return ^STDeferred *(STDeferredCallback callback) {
        return [self always:callback];
    };
}

- (STDeferred *(^)(id))resolve
{
    return ^STDeferred *(id resultObject) {
        [self resolve:resultObject];
        return self;
    };
}

- (STDeferred *(^)(id))reject
{
    return ^STDeferred *(id resultObject) {
        [self reject:resultObject];
        return self;
    };
}

- (STDeferred *(^)(STDeferredNextCallback, STDeferredNextCallback))pipe
{
    return ^STDeferred *(STDeferredNextCallback successBlock, STDeferredNextCallback failBlock) {
        return [self pipe:successBlock fail:failBlock];
    };
}

- (STDeferred *(^)(STDeferredNextCallback))next
{
    return ^STDeferred *(STDeferredNextCallback block) {
        return [self next:block];
    };
}

- (void)cancel
{
    if(_state == STDeferredStateUnresolved) {
        if(_canceller) {
            _canceller();
        }
        NSError *cancelError = [NSError errorWithDomain:STDeferredErrorDomain
                                                   code:STDeferredErrorCancel
                                               userInfo:nil];
        [self reject:cancelError];
    }
}

- (STDeferred *)canceller:(STDeferredCancelBlock)block
{
    _canceller = [block copy];
    return self;
}

- (STDeferred *(^)(STDeferredCancelBlock))canceller
{
    return ^STDeferred *(STDeferredCancelBlock cancelBlock) {
        return [self canceller:cancelBlock];
    };
}

@end
