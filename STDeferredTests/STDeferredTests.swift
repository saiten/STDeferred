//
//  STDeferredTest.swift
//  STDeferred
//
//  Copyright © 2015 saiten. All rights reserved.
//

import XCTest
import STDeferred
import Result

private enum TestError : String, ErrorType {
    case Fail = "fail"
    case First = "first"
    case Second = "second"
    case Third = "third"
}

class STDeferredTest: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testSuccess() {
        var count = 1
        let deferred = Deferred<String, TestError>()
        deferred
        .success { (value) in
            XCTAssertEqual("success", value)
            XCTAssertEqual(1, count++)
        }.success { (value) in
            XCTAssertEqual("success", value)
            XCTAssertEqual(2, count++)
        }.failure { (error) in
            XCTFail()
        }.resolve("success")
        
        XCTAssertEqual(3, count)
    }
    
    func testSuccessAfterResolve() {
        let deferred = Deferred<String, TestError>()
        deferred.resolve("hoge")
        
        deferred
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }.failure { (error) in
            XCTFail()
        }
    }
    
    
    func testFailure() {
        var count = 1
        let deferred = Deferred<String, TestError>()
        deferred
        .success { (value) in
            XCTFail()
        }.failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
            XCTAssertEqual(1, count++)
        }.failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
            XCTAssertEqual(2, count++)
        }.reject(.Fail)
        
        XCTAssertEqual(3, count)
    }
    
    func testFailureAfterReject() {
        let deferred = Deferred<String, TestError>()
        deferred.reject(.Fail)
        
        deferred
        .success { (value) in
            XCTFail()
        }.failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
    }
    
    func testComplete() {
        Deferred<String, TestError>()
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }
        .failure { (error) in
            XCTFail()
        }
        .complete { (result) in
            switch result! {
            case .Success(let value):
                XCTAssertEqual("hoge", value)
            case .Failure:
                XCTFail()
            }
        }
        .resolve("hoge")
        
        Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        .complete { (result) in
            switch result! {
            case .Success:
                XCTFail()
            case .Failure(let error):
                XCTAssertEqual("fail", error.rawValue)
            }
        }
        .reject(.Fail)
    }
    
    
    func testCompleteAfterResolve() {
        let deferred = Deferred<String, TestError>()
        deferred.resolve("hoge")
        
        deferred
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }
        .failure { (error) in
            XCTFail()
        }
        .complete { (result) in
            switch result! {
            case .Success(let value):
                XCTAssertEqual("hoge", value)
            case .Failure:
                XCTFail()
            }
        }

        let deferred2 = Deferred<String, TestError>()
        deferred2.reject(.Fail)
        
        deferred2
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        .complete { (result) in
            switch result! {
            case .Success:
                XCTFail()
            case .Failure(let error):
                XCTAssertEqual("fail", error.rawValue)
            }
        }
        .reject(.Fail)
    }

    func testPipe() {
        let expectation = self.expectationWithDescription("testPipe")

        var count = 0
        
        let deferred = Deferred<String, TestError>()
        deferred
        .pipe { (result) -> Deferred<Int, TestError> in
            switch result! {
            case .Success(let value):
                XCTAssertEqual("start", value)
            case .Failure:
                XCTFail()
            }
            let d2 = Deferred<Int, TestError>()
            
            let delay = 1.0 * Double(NSEC_PER_SEC)
            let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
            
            dispatch_after(popTime, dispatch_get_main_queue()) {
                XCTAssertEqual(1, count++)
                d2.resolve(12345)
            }
            return d2
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .Success(let value):
                XCTAssertEqual(12345, value)
            case .Failure:
                XCTFail()
            }
            XCTAssertEqual(2, count++)
            return Result<String, TestError>(value: "second")
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .Success(let value):
                XCTAssertEqual("second", value)
            case .Failure:
                XCTFail()
            }
            XCTAssertEqual(3, count++)
            return Result<String, TestError>(value: "third")
        }
        .success { (value) in
            XCTAssertEqual("third", value)
            XCTAssertEqual(4, count++)
            expectation.fulfill()
        }
        .failure { (error) in
            XCTFail()
        }
    
        deferred.resolve("start")
        XCTAssertEqual(0, count++)
    
        self.waitForExpectationsWithTimeout(5.0) { (error) in }
    }
    
    func testPipeFailure() {
        let expectation = self.expectationWithDescription("testPipeFailure")
        
        var count = 0
        
        let deferred = Deferred<String, TestError>()
        deferred
        .pipe { (result) -> Deferred<Int, TestError> in
            switch result! {
            case .Success:
                XCTFail()
            case .Failure(let error):
                XCTAssertEqual("fail", error.rawValue)
            }
            let d2 = Deferred<Int, TestError>()
            
            let delay = 1.0 * Double(NSEC_PER_SEC)
            let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
            
            dispatch_after(popTime, dispatch_get_main_queue()) {
                XCTAssertEqual(1, count++)
                d2.reject(TestError.First)
            }
            return d2
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .Success:
                XCTFail()
            case .Failure(let error):
                XCTAssertEqual("first", error.rawValue)
            }
            XCTAssertEqual(2, count++)
            return Result<String, TestError>(error: TestError.Second)
        }
        .pipe { (result) -> Result<String, TestError>? in
            switch result! {
            case .Success:
                XCTFail()
            case .Failure(let error):
                XCTAssertEqual("second", error.rawValue)
            }
            XCTAssertEqual(3, count++)
            return Result<String, TestError>(error: TestError.Third)
        }
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("third", error!.rawValue)
            XCTAssertEqual(4, count++)
            expectation.fulfill()
        }
        
        deferred.reject(.Fail)
        XCTAssertEqual(0, count++)
        
        self.waitForExpectationsWithTimeout(5.0) { (error) in }
    }
    
    func testThen() {
        let expectation = self.expectationWithDescription("testThen")
        
        var count = 0
        
        let deferred = Deferred<String, TestError>()
        deferred
        .then { (value) -> String in
            XCTAssertEqual("start", value)
            XCTAssertEqual(1, count++)
            return "first"
        }
        .then { (value) -> Result<String, TestError> in
            XCTAssertEqual("first", value)
            XCTAssertEqual(2, count++)
            return Result<String, TestError>(value: "second")
        }
        .then { (value) -> Deferred<String, TestError> in
            XCTAssertEqual("second", value)
            XCTAssertEqual(3, count++)
            return Deferred<String, TestError>(result: Result<String, TestError>(value: "third"))
        }
        .success { (value) in
            XCTAssertEqual("third", value)
            XCTAssertEqual(4, count++)
            expectation.fulfill()
        }
        .failure { (error) in
            XCTFail()
        }
        
        XCTAssertEqual(0, count++)
        deferred.resolve("start")
        XCTAssertEqual(5, count++)

        self.waitForExpectationsWithTimeout(5.0) { (error) in }
    }
    
    func testWhen() {        
        let expectation = self.expectationWithDescription("testWhen")
        
        let d1 = Deferred<String, TestError>()
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
            d1.resolve("1 sec")
        }

        let d2 = Deferred<String, TestError>()
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
            d2.resolve("2 sec")
        }

        when(d1, d2).success { (values: [String]) in
            XCTAssertEqual(2, values.count)
            XCTAssertEqual("1 sec", values[0])
            XCTAssertEqual("2 sec", values[1])
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(5.0) { (error) in }
    }

    func testWhenMultiType() {
        let expectation = self.expectationWithDescription("testWhenMultiType")
        
        let d1 = Deferred<String, TestError>()
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
            d1.resolve("1 sec")
        }
        
        let d2 = Deferred<Int, TestError>()
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
            d2.resolve(2)
        }
        
        when(d1, d2).success { (v1, v2) in
            XCTAssertEqual("1 sec", v1)
            XCTAssertEqual(2, v2)
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(5.0) { (error) in }
    }
    
    func testCancel() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
        }
        
        deferred.cancel()
    }

    func testCancelAfterResolve() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTAssertEqual("hoge", value)
        }
        .failure { (error) in
            XCTFail()
        }
        .canceller {
            XCTFail()
        }

        deferred.resolve("hoge")
        deferred.cancel()
    }

    func testCancelAfterReject() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        .canceller {
            XCTFail()
        }
        
        deferred.reject(.Fail)
        deferred.cancel()
    }
    
    func testCancelUndefinedCanceller() {
        let deferred = Deferred<String, TestError>()
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
        }
        
        deferred.cancel()
        deferred.resolve("hoge")
    }
    
    func testCancelWhen() {
        var count = 0;
        
        let d1 = Deferred<String, TestError>()
        .failure { (error) in
            XCTAssert(error == nil)
        }
        .canceller { XCTAssertEqual(1, count++) }
        
        let d2 = Deferred<String, TestError>()
        .failure { (error) in
            XCTAssert(error == nil)
        }
        .canceller { XCTAssertEqual(2, count++) }

        let deferred = when(d1, d2)
        .success { (s1, s2) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
            XCTAssertEqual(3, count++)
        }

        XCTAssertEqual(0, count++)
        deferred.cancel()
        XCTAssertEqual(4, count)
    }
    
    func testCancelPipe() {
        var count = 0;
        
        let d1 = Deferred<String, TestError>()
        d1.canceller {
            XCTAssertEqual(1, count++)
        }

        let d2 = d1.pipe { $0 }
        let d3 = d2.pipe { $0 }
        
        d3.failure { (error) in
            XCTAssert(error == nil)
            XCTAssertEqual(2, count++)
        }

        XCTAssertEqual(0, count++)
        d3.cancel()
    }
    
    func testCancelPipeHalfway() {
        var count = 0
        
        let deferred = Deferred<String, TestError>().resolve("start")
        .pipe { _ in
            return Deferred<String, TestError>()
            .success { _ in
                XCTFail()
            }
            .failure { _ in
                XCTAssertEqual(2, count++)
            }
            .canceller {
                XCTAssertEqual(1, count++)
            }
        }
        .pipe { (result) -> Result<String, TestError>? in
            XCTAssert(result == nil)
            return result
        }
        
        XCTAssertEqual(0, count++)
        
        deferred
        .success { _ in
            XCTFail()
        }
        .failure { _ in
            XCTAssertEqual(3, count++)
        }
        
        deferred.cancel()
    }
    
    func testCancelPipeLast() {
        var count = 0
        
        let deferred = Deferred<String, TestError>().resolve("start")
        .pipe { (result) -> Deferred<String, TestError> in
            XCTAssertEqual("start", result!.value!)
            return Deferred<String, TestError>().resolve("first")
                .canceller { XCTFail() }
        }
        .pipe { (result) -> Deferred<String, TestError> in
            XCTAssertEqual("first", result!.value!)
            return Deferred<String, TestError>().resolve("second")
                .canceller { XCTFail() }
        }
        .pipe { _ in
            return Deferred<String, TestError>()
            .success { _ in
                XCTFail()
            }
            .failure { _ in
                XCTAssertEqual(2, count++)
            }
            .canceller {
                XCTAssertEqual(1, count++)
            }
        }
        
        XCTAssertEqual(0, count++)
        
        deferred
        .success { _ in
            XCTFail()
        }
        .failure { _ in
            XCTAssertEqual(3, count++)
        }
        
        deferred.cancel()
    }
    
    func testCancelInPipe() {
        let expectation = self.expectationWithDescription("testCancelInPipe")
        
        var count = 0
        
        let deferred = Deferred<String, TestError>()
        
        let d1 = Deferred<Void, TestError>().resolve()
        .pipe { _ -> Deferred<Void, TestError> in
            XCTAssertEqual(0, count++)
            return Deferred<Void, TestError>().resolve().canceller { XCTFail() }
        }
        .pipe { _ -> Deferred<Void, TestError> in
            XCTAssertEqual(1, count++)

            let d = Deferred<Void, TestError>()
            .canceller {
                XCTAssertEqual(4, count++)
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
                XCTAssertEqual(5, count++)
                XCTAssertTrue(d.isCancelled)
                d.resolve()
            }
            
            return d
        }
        .pipe { $0 }
        .pipe { $0 }
        
        let d2 = Deferred<Void, TestError>().resolve()
        .canceller { XCTFail() }
        .success { XCTAssertTrue(true) }

        let setup = when(d1, d2)
        .success {
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
            deferred.reject(.Fail)
            expectation.fulfill()
        }
        
        deferred.canceller {
            XCTAssertEqual(3, count++)
            setup.cancel()
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
            XCTAssertEqual(2, count++)
            deferred.cancel()
        }

        self.waitForExpectationsWithTimeout(5.0) { _ in }
    }
    
    func testInitClosure() {
        let expectation = self.expectationWithDescription("testInitClosure")
        
        Deferred<String, TestError> { (resolve, _, _) in
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
                resolve("success")
            }
        }
        .success { (value) in
            XCTAssertEqual("success", value)
        }
        .failure { _ in
            XCTFail()
        }

        Deferred<String, TestError> { (_, reject, _) in
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
                reject(.Fail)
            }
        }
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }

        Deferred<String, TestError> { (_, _, cancel) in
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
                cancel()
            }
        }
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssert(error == nil)
            expectation.fulfill()
        }

        self.waitForExpectationsWithTimeout(5.0) { _ in }
    }
    
    func testSync() {
        let d1 = Deferred<String, TestError>()

        Deferred<String, TestError>().sync(d1)
        .success { (value) in
            XCTAssertEqual("success", value)
        }
        .failure { (error) in
            XCTFail()
        }
        d1.resolve("success")
        
        let d2 = Deferred<String, TestError>()
        Deferred<String, TestError>().sync(d2)
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertEqual("fail", error!.rawValue)
        }
        d2.reject(.Fail)
        
        let d3 = Deferred<String, TestError>()
        Deferred<String, TestError>().sync(d3)
        .success { (value) in
            XCTFail()
        }
        .failure { (error) in
            XCTAssertNil(error)
        }
        d3.cancel()
    }
    
}

