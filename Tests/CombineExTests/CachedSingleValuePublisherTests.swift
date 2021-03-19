//
//  CachedSingleValuePublisherTests.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 1/29/21.
//  Copyright © 2021 Rocket Insights. All rights reserved.
//

import XCTest
import Combine
import CombineEx

class CachedSingleValuePublisherTests: XCTestCase {
    func testBasic() {
        var subscriptions = Set<AnyCancellable>()
        var count = 0
        let publish2 = cached(cacheMaxTime: 0, { Just(2) })
        publish2().wrapIfPublisher { $0 }.sink {
            count += 1
            XCTAssertEqual($0, 2)
        }
        .store(in: &subscriptions)

        XCTAssertEqual(count, 1)
    }

    func testAsync() {
        let expectation = XCTestExpectation()
        var subscriptions = Set<AnyCancellable>()

        let publish2 = cached(cacheMaxTime: 0.001, { Just(2).delay(for: .seconds(0.001), scheduler: DispatchQueue.main) })
        var count = 0
        let now = DispatchTime.now()
        let maxCount = 10000
        let delta = 0.001
        for loopCount in 0..<maxCount {
            DispatchQueue.main.asyncAfter(deadline: now + delta * Double(loopCount)) {
                publish2().wrapIfPublisher { $0 }.sink {
                    count += 1
                    XCTAssertEqual($0, 2)
                    if count == maxCount - 1 {
                        expectation.fulfill()
                    }
                }
                .store(in: &subscriptions)
            }
        }

        wait(for: [expectation], timeout: delta * Double(maxCount) + 10)
        XCTAssertEqual(count, maxCount)
    }
}
