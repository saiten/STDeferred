//
//  STDeferred.swift
//  STDeferred
//
//  Copyright © 2015 saiten. All rights reserved.
//

import Foundation
import Result

public class Deferred<T, E: ErrorType> {
    
    // MARK: - Private properties
    
    private var successHandlers: [T -> Void] = []
    private var failureHandlers: [E? -> Void] = []
    private var completeHandlers: [Result<T, E>? -> Void] = []
    private var cancelHandlers: [(Void -> Void)] = []
    
    // MARK: - Properties
    
    public private(set) var result: Result<T, E>?
    
    public private(set) var isCancelled: Bool = false
    
    public var isUnresolved: Bool {
        get {
            return self.result == nil && !self.isCancelled
        }
    }
    
    public var isRejected: Bool {
        get {
            if self.isCancelled {
                return true
            }
            
            guard let result = self.result else {
                return false
            }
            if case .Failure(_) = result {
                return true
            } else {
                return false
            }
        }
    }
    
    public var isResolved: Bool {
        get {
            if self.isCancelled {
                return false
            }

            guard let result = self.result else {
                return false
            }
            if case .Success(_) = result {
                return true
            } else {
                return false
            }
        }
    }
    
    public var resolve: T -> Deferred {
        get {
            return { (value: T) in
                return self._resolve(value)
            }
        }
    }
    
    public var reject: E -> Deferred {
        get {
            return { (error: E) in
                return self._reject(error)
            }
        }
    }
    
    // MARK: - Methods
    
    public init() {
    }
    
    public init(@noescape initClosure: (resolve: T -> Void, reject: E -> Void, cancel: Void -> Void) -> Void) {
        initClosure(resolve: { self.resolve($0) }, reject: { self.reject($0) }, cancel: { self.cancel() })
    }
    
    public init(result: Result<T, E>) {
        self.result = result
    }
    
    public convenience init(value: T) {
        self.init(result: .Success(value))
    }
    
    public convenience init(error: E) {
        self.init(result: .Failure(error))
    }

//    deinit {
//        if let result = self.result {
//            NSLog("deferred deinit = " + result.description)
//        } else {
//            NSLog("deferred deinit")
//        }
//    }
    
    private func _resolve(value: T) -> Self {
        if self.isUnresolved {
            fire(.Success(value))
        }
        return self;
    }
    
    private func _reject(error: E) -> Self {
        if self.isUnresolved {
            fire(.Failure(error))
        }
        return self;
    }
    
    private func fire(result: Result<T, E>?) {
        self.result = result
        
        if let result = result {
            switch result {
            case .Success(let value):
                for handler in successHandlers {
                    handler(value)
                }
            case .Failure(let error):
                for handler in failureHandlers {
                    handler(error)
                }
            }
        } else {
            for handler in failureHandlers {
                handler(nil)
            }
        }
        
        for handler in completeHandlers {
            handler(result)
        }
        
        successHandlers.removeAll()
        failureHandlers.removeAll()
        completeHandlers.removeAll()
        cancelHandlers.removeAll()
    }
    
    public func cancel() -> Self {
        if self.isUnresolved {
            for handler in cancelHandlers {
                handler()
            }
            self.isCancelled = true
            fire(nil)
        }
        return self
    }
    
    public func success(handler: T -> Void) -> Self {
        if self.isResolved {
            handler(self.result!.value!)
        } else {
            successHandlers.append(handler)
        }
        return self
    }
    
    public func failure(handler: E? -> Void) -> Self {
        if self.isRejected {
            handler(self.result?.error)
        } else {
            failureHandlers.append(handler)
        }
        return self
    }
    
    public func canceller(handler: Void -> Void) -> Self {
        if self.isUnresolved {
            cancelHandlers.append(handler)
        }
        return self
    }
    
    public func complete(handler: Result<T, E>? -> Void) -> Self {
        if !self.isUnresolved {
            handler(result)
        } else {
            completeHandlers.append(handler)
        }
        return self
    }

    public func asVoid() -> Deferred<Void, E> {
        return self.then { (value) -> Void in }
    }

    // MARK: then

    public func then<T2>(handler: T -> Deferred<T2, E>) -> Deferred<T2, E> {
        return self.pipe { result -> Deferred<T2, E> in
            if let result = result {
                switch result {
                case .Success(let value):
                    return handler(value)
                case .Failure(let error):
                    return Deferred<T2, E>(error: error)
                }
            } else {
                return Deferred<T2, E>().cancel()
            }
        }
    }
    
    public func then<T2>(handler: T -> Result<T2, E>) -> Deferred<T2, E> {
        return self.then { value in
            return Deferred<T2, E>(result: handler(value))
        }
    }
    
    public func then<T2>(handler: T -> T2) -> Deferred<T2, E> {
        return self.then { value in
            return .Success(handler(value))
        }
    }
    
    // MARK: pipe

    public func pipe<T2, E2>(handler: Result<T, E>? -> Result<T2, E2>?) -> Deferred<T2, E2> {
        return self.pipe { result -> Deferred<T2, E2> in
            if let result2 = handler(result) {
                return Deferred<T2, E2>(result: result2)
            } else {
                return Deferred<T2, E2>().cancel()
            }
        }
    }
    
    public func pipe<T2, E2>(handler: Result<T, E>? -> Deferred<T2, E2>) -> Deferred<T2, E2> {
        let deferred = Deferred<T2, E2>()
        
        deferred.canceller {
            self.cancel()
        }
        
        self.complete { result in
            let resultDeferred = handler(result)
            
            resultDeferred.complete { result in
                if let result = result {
                    switch result {
                    case .Success(let value):
                        deferred.resolve(value)
                    case .Failure(let error):
                        deferred.reject(error)
                    }
                }
            }
            deferred.canceller {
                resultDeferred.cancel()
            }
        }
        
        return deferred
    }
}

// MARK: - when

public func when<T, E>(deferreds: [Deferred<T, E>]) -> Deferred<Void, E> {
    let whenDeferred = Deferred<Void, E>()
    
    var unresolveCount = deferreds.count
    
    guard unresolveCount > 0 else {
        return whenDeferred.resolve()
    }
    
    for deferred in deferreds {
        deferred.complete { result in
            if let result = result {
                switch result {
                case .Success:
                    if --unresolveCount == 0 {
                        whenDeferred.resolve()
                    }
                case .Failure(let error):
                    whenDeferred.reject(error)
                }
            }
        }
        whenDeferred.canceller {
            deferred.cancel()
        }
    }
    
    return whenDeferred
}

public func when<T, E>(deferreds: [Deferred<T, E>]) -> Deferred<[T], E> {
    return when(deferreds).then { () -> [T] in
        return deferreds.map { $0.result!.value! }
    }
}

public func when<T, E>(deferreds: Deferred<T, E>...) -> Deferred<[T], E> {
    return when(deferreds)
}

public func when<E>(deferreds: Deferred<Void, E>...) -> Deferred<Void, E> {
    return when(deferreds)
}

public func when<T, U, E>(dt: Deferred<T, E>, _ du: Deferred<U, E>) -> Deferred<(T, U), E> {
    return when(dt.asVoid(), du.asVoid()).then { () -> (T, U) in
        return (dt.result!.value!, du.result!.value!)
    }
}

public func when<T, U, V, E>(dt: Deferred<T, E>, _ du: Deferred<U, E>, _ dv: Deferred<V, E>) -> Deferred<(T, U, V), E> {
    return when(dt.asVoid(), du.asVoid(), dv.asVoid()).then { () -> (T, U, V) in
        return (dt.result!.value!, du.result!.value!, dv.result!.value!)
    }
}

public func when<T, U, V, W, E>(dt: Deferred<T, E>, _ du: Deferred<U, E>, _ dv: Deferred<V, E>, _ dw: Deferred<W, E>) -> Deferred<(T, U, V, W), E> {
    return when(dt.asVoid(), du.asVoid(), dv.asVoid(), dw.asVoid()).then { () -> (T, U, V, W) in
        return (dt.result!.value!, du.result!.value!, dv.result!.value!, dw.result!.value!)
    }
}

