//
//  Observable.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 10/8/21.
//

import Combine
import FoundationEx

public class ObservableValue<T>: ObservableObject {
    @MainActor
    @Published public private(set) var value: T

    @MainActor
    public init(_ value: T) {
        self.value = value
    }

    @MainActor
    public func update(_ newValue: T) {
        value = newValue
    }
}

extension ObservableValue where T: Equatable {
    @MainActor
    public func maybeUpdate(_ newValue: T) {
        if value != newValue {
            value = newValue
        }
    }
}

extension ObservableValue: IdentifiableAsSelf {
}

extension ObservableValue: Equatable {
    public static func == (lhs: ObservableValue, rhs: ObservableValue) -> Bool {
        lhs === rhs
    }
}

extension ObservableValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(address(of: self))
    }
}

extension ObservableValue {
    @MainActor
    convenience public init<W>() where T == W? {
        self.init(nil)
    }
}
