//
//  Future.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 7/21/20.
//  Copyright © 2021 Rocket Insights. All rights reserved.
//

import Foundation
import Combine

typealias Future = LazyFuture

public struct LazyFuture<Output, Failure: Error>: Publisher {
    public typealias Promise = (Result<Output, Failure>) -> Void
    private let task: (@escaping Promise) -> Void

    public init(_ task: @escaping (@escaping Promise) -> Void) {
        self.task = task
    }

    public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        let subscription = FutureSubscription<S>(self, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }

    private final class FutureSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {
        private let publisher: LazyFuture
        private var subscriber: S?

        init(_ publisher: LazyFuture, subscriber: S) {
            self.publisher = publisher
            self.subscriber = subscriber
        }

        func cancel() {
            subscriber = nil
        }

        func request(_ demand: Subscribers.Demand) {
            guard let subscriber = subscriber else { return }
            publisher.task { result in
                switch result {
                case .success(let value):
                    _ = subscriber.receive(value)
                    subscriber.receive(completion: .finished)

                case .failure(let error):
                    subscriber.receive(completion: .failure(error))
                }

                self.subscriber = nil
            }
        }
    }
}
