//
//  Publisher.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 7/11/20.
//  Copyright © 2021 Rocket Insights. All rights reserved.
//

import Foundation
import Combine
import Tagged

// MARK:- SingleValuePublisher

public protocol SingleValuePublisher: Publisher {}
public enum SingleValueTag {}
public enum SomeValuesTag {}

extension Publishers.First: SingleValuePublisher {}
extension Future: SingleValuePublisher {}
extension Just: SingleValuePublisher {}
extension Fail: SingleValuePublisher {}
extension Combine.Empty: SingleValuePublisher {}
extension URLSession.DataTaskPublisher: SingleValuePublisher {}
extension AnyTaggedPublisher: SingleValuePublisher where Tag == SingleValueTag {}
extension Publishers.FlatMap: SingleValuePublisher where Upstream: SingleValuePublisher, NewPublisher: SingleValuePublisher {}
extension Publishers.ReplaceError: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.Catch: SingleValuePublisher where Upstream: SingleValuePublisher, NewPublisher: SingleValuePublisher {}
extension Publishers.AssertNoFailure: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.Collect: SingleValuePublisher {}
extension Publishers.Print: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.HandleEvents: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.SwitchToLatest: SingleValuePublisher where Upstream: SingleValuePublisher, Upstream.Output: SingleValuePublisher {}
extension Publishers.Map: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.CompactMap: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.TryMap: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.MapError: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.Delay: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.ReceiveOn: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.SubscribeOn: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.Share: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.Zip: SingleValuePublisher where A: SingleValuePublisher, B: SingleValuePublisher {}
extension Publishers.Zip3: SingleValuePublisher where A: SingleValuePublisher, B: SingleValuePublisher, C: SingleValuePublisher {}
extension Publishers.Last: SingleValuePublisher {}
extension Publishers.RemoveDuplicates: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.Filter: SingleValuePublisher where Upstream: SingleValuePublisher {}
extension Publishers.FirstWhere: SingleValuePublisher {}

public typealias AnySingleValuePublisher<Output, Failure> = AnyTaggedPublisher<Output, Failure, SingleValueTag> where Failure: Error
public typealias AnySomeValuesPublisher<Output, Failure> = AnyTaggedPublisher<Output, Failure, SomeValuesTag> where Failure: Error

public extension Publisher {
    /// A publisher for keyPath properties. It's optimized for use with UI to not publish duplicates and avoid needless
    /// UI rendering. Using it should have the same semantics as another implementation that does not remove duplictaes.
    func property<T: Equatable>(_ keyPath: KeyPath<Output, T>) -> AnyPublisher<T, Failure> {
        map(keyPath).removeDuplicates().eraseToAnyPublisher()
    }

    func property<T>(_ keyPath: KeyPath<Output, T>, _ equal: @escaping (T, T) -> Bool) -> AnyPublisher<T, Failure> {
        map(keyPath).removeDuplicates(by: equal).eraseToAnyPublisher()
    }
}

extension Publisher {
    fileprivate func eraseToTaggedPublisher<Tag>() -> AnyTaggedPublisher<Output, Failure, Tag> {
        AnyTaggedPublisher(eraseToAnyPublisher())
    }
}

public extension Publisher where Self: SingleValuePublisher {
    func eraseType() -> AnySingleValuePublisher<Output, Failure> {
        AnyTaggedPublisher(eraseToAnyPublisher())
    }
}

// MARK:- serialFlatMap

public extension Publisher {
    func serialFlatMap<T, P>(_ transform: @escaping (Self.Output) -> P)
    -> Publishers.FlatMap<P, Self> where T == P.Output, P: Publisher, Self.Failure == P.Failure
    {
        return flatMap(maxPublishers: .max(1), transform)
    }
}

// MARK:- flatMapLatest

public extension Publisher {
    func flatMapLatest<T, P: Publisher>(_ transform: @escaping (Self.Output) -> P)
        -> Publishers.SwitchToLatest<P, Publishers.Map<Self, P>> where T == P.Output, Self.Failure == P.Failure
    {
        map { transform($0) }.switchToLatest()
    }
}

// MARK:- flatMapValue

public extension Publisher where Self: SingleValuePublisher {
    func flatMapValue<T, P: Publisher>(_ transform: @escaping (Self.Output) -> P)
    -> Publishers.SwitchToLatest<P, Publishers.Map<Self, P>> where T == P.Output, Self.Failure == P.Failure
    {
        flatMapLatest(transform)
    }
}

// MARK:- asResult

public extension Publisher where Self: SingleValuePublisher{
    func asResult() -> AnySingleValuePublisher<Result<Output, Failure>, Never> {
        map {.success($0) }.replaceError { .failure($0) }.eraseType()
    }
}

// MARK:- mapWithSideEffect

public extension Publisher {
    func mapWithSideEffect<T>(_ transformWithEffect: @escaping (Output) -> T) -> Publishers.Map<Self, T> {
        map(transformWithEffect)
    }
}

// MARK:- side effects

public extension Publisher {
    func sideEffect<P: SingleValuePublisher>(_ handler: @escaping (Output) -> P) -> Publishers.HandleEvents<Self>
    where P.Output == Void {
        handleEvents(
            receiveOutput: {
                handler($0).runAsSideEffect()
            }
        )
    }

    func sideEffect(_ sideEffect: @escaping (Output) -> Void) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveOutput: sideEffect)
    }
}

public extension Publisher where Self: SingleValuePublisher, Output == Void {
    func runAsSideEffect(completion handler: ((Failure?) -> Void)? = nil) {
        var subscription: AnyCancellable?
        subscription = self.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    handler?(nil)

                case .failure(let error):
                    if let handler = handler {
                        handler(error)
                    }
                    else {
                        CombineEx.env.logGeneralError(error)
                    }
                }
                subscription?.cancel()
            },
            receiveValue: { _ in }
        )
    }
}

public extension Publisher where Self: SingleValuePublisher {
    func convertToSideEffect(_ sideEffect: @escaping (Output) -> Void) -> AnySingleValuePublisher<Void, Never> {
        handleEvents(receiveOutput: sideEffect)
        .map { _ in () }
        .catch { error -> AnySingleValuePublisher<Void, Never> in
            CombineEx.env.logGeneralError(error)
            return Just(()).eraseType()
        }
        .eraseType()
    }
}

// MARK:- error handling

public extension Publisher {
    func replaceError(_ handler: @escaping(Failure) -> Output) -> Publishers.Catch<Self, Just<Self.Output>>  {
        self.catch { Just(handler($0)) }
    }

    func replaceErrorWithNil() -> Publishers.ReplaceError<Publishers.Map<Self, Self.Output?>> {
        map { $0 as Output? }.replaceError(with: nil)
    }

    func replaceErrorWithNil<T>() -> Publishers.ReplaceError<Self> where Output == T? {
        replaceError(with: nil)
    }
}

public extension Publisher {
    func forceErrorType<T: Error>(_ type: T.Type) -> Publishers.MapError<Self, T> {
        mapError { $0 as! T } // swiftlint:disable:this force_cast
    }

    func addErrorType<T: Error>(_ type: T.Type) -> Publishers.MapError<Self, T> where Failure == Never {
        mapError { _ -> T in }
    }
}

public extension Publisher where Self: SingleValuePublisher {
    func sideEffectIfError(_ handler: @escaping (Failure) -> Void) -> AnySingleValuePublisher<Output, Failure> {
        self.handleEvents(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    handler(error)
                case .finished:
                    break
                }
            }
        )
        .eraseType()
    }
}

// MARK:- Cancel

public enum Cancel: Error {
    case cancel
    public static let value = cancel
}

public extension Publisher {
    func ignoreCancel() -> Publishers.ReplaceError<Self> where Output == Void, Failure == Cancel {
        replaceError(with: ())
    }
}

public func makePublisher<T>(_ f: @escaping () async -> T) -> AnySingleValuePublisher<T, Never> {
    LazyFuture { promise in
        Task {
            promise(.success(await f()))
        }
    }
    .eraseType()
}

public func makePublisher<T>(_ f: @escaping () async throws -> T) -> AnySingleValuePublisher<T, Error> {
    LazyFuture { promise in
        Task {
            do {
                try promise(.success(await f()))
            }
            catch {
                promise(.failure(error))
            }
        }
    }
    .eraseType()
}

public extension SingleValuePublisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            self.asResult()
                .sideEffect {
                    continuation.resume(with: $0)
                }
                .map { _ in }
                .runAsSideEffect()
        }
    }
}

public extension SingleValuePublisher where Failure == Never {
    func async() async -> Output {
        await withCheckedContinuation { continuation in
            self.sideEffect {
                continuation.resume(returning: $0)
            }
            .map { _ in }
            .runAsSideEffect()
        }
    }
}

// MARK:- AsyncPublisher

@available(iOS 15.0, *)
public extension AsyncPublisher {
    func get(callback: @escaping (Element) async -> Void) async {
        for await elem in self {
            await callback(elem)
        }
    }
}
