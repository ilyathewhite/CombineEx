//
//  Observable.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 10/8/21.
//

import Combine
import FoundationEx

public class ObservableValue<T>: ObservableObject {
    @Published public private(set) var value: T

    public init(_ value: T) {
        self.value = value
    }

    public func update(_ newValue: T) {
        value = newValue
    }
}

extension ObservableValue where T: Equatable {
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
    convenience public init<W>() where T == W? {
        self.init(nil)
    }
}
