//
//  AnyTaggedPublisher.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 12/25/20.
//  Copyright © 2021 Rocket Insights. All rights reserved.
//

import Foundation
import Combine

public struct AnyTaggedPublisher<Output, Failure: Error, Tag>: Publisher {
    typealias Upstream = AnyPublisher<Output, Failure>
    let upstream: Upstream

    init(_ upstream: Upstream) {
        self.upstream = upstream
    }

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        upstream.receive(subscriber: subscriber)
    }
}
