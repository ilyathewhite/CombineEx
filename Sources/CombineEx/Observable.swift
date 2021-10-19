//
//  Observable.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 10/8/21.
//

import Combine

public class ObservableValue<T>: ObservableObject {
    @Published public var value: T

    public init(_ value: T) {
        self.value = value
    }
}

extension ObservableValue: Identifiable where T: Identifiable {
    public var id: T.ID {
        value.id
    }
}

extension ObservableValue: Equatable where T: Identifiable {
    public static func == (lhs: ObservableValue<T>, rhs: ObservableValue<T>) -> Bool {
        lhs.id == rhs.id
    }
}

extension ObservableValue: Hashable where T: Identifiable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ObservableValue {
    convenience public init<W>() where T == W? {
        self.init(nil)
    }
}
