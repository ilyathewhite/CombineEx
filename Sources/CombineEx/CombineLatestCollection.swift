//
//  CombineLatestCollection.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 3/14/22.
//  Copyright © 2022 Rocket Insights. All rights reserved.
//

import Foundation
import Combine

// https://danieltull.co.uk/blog/2019/08/04/combine-latest-collection/

public struct CombineLatestCollection<Publishers> where Publishers: Collection, Publishers.Element: Publisher {
    public typealias Output = [Publishers.Element.Output]
    public typealias Failure = Publishers.Element.Failure

    private let publishers: Publishers

    public init(_ publishers: Publishers) {
        self.publishers = publishers
    }
}

extension CombineLatestCollection: Publisher {
    public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, S.Input == Output {
        let subscription = Subscription(publishers: publishers, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

extension CombineLatestCollection {
    public final class Subscription<Subscriber>: Combine.Subscription where
        Subscriber: Combine.Subscriber,
        Subscriber.Failure == Failure,
        Subscriber.Input == Output
    {
        private let subscribers: [AnyCancellable]

        fileprivate init(publishers: Publishers, subscriber: Subscriber) {
            var values: [Publishers.Element.Output?] = Array(repeating: nil, count: publishers.count)
            var completions = 0
            var hasCompleted = false
            var lock = pthread_mutex_t()

            subscribers = publishers.enumerated().map { index, publisher in
                publisher.sink(
                    receiveCompletion: { completion in
                        pthread_mutex_lock(&lock)
                        defer { pthread_mutex_unlock(&lock) }

                        guard case .finished = completion else {
                            subscriber.receive(completion: completion)
                            hasCompleted = true
                            return
                        }

                        completions += 1

                        if completions == publishers.count {
                            subscriber.receive(completion: completion)
                            hasCompleted = true
                        }

                    },
                    receiveValue: { value in
                        pthread_mutex_lock(&lock)
                        defer { pthread_mutex_unlock(&lock) }

                        guard !hasCompleted else { return }
                        values[index] = value

                        let current = values.compactMap { $0 }
                        if current.count == publishers.count {
                            _ = subscriber.receive(current)
                        }
                    }
                )
            }
        }

        // ignore demand for now; usually it's unlimited
        public func request(_ demand: Subscribers.Demand) {}

        public func cancel() {
            subscribers.forEach { $0.cancel() }
        }
    }
}

extension Collection where Element: Publisher {
    public var combineLatest: CombineLatestCollection<Self> {
        CombineLatestCollection(self)
    }
}
