//
//  Array.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 3/30/22.
//  Copyright © 2021 Rocket Insights. All rights reserved.
//

import Foundation
import Combine

extension Array {
    public func processAll<E: Error>(_ f: @escaping (Element) -> AnySingleValuePublisher<Void, E>) -> AnySingleValuePublisher<Void, E> {
        if isEmpty {
            return Just(()).addErrorType(E.self).eraseType()
        }
        else {
            return map(f).processAll()
        }
    }
}

extension Array {
    public func processAll<E: Error>() -> AnySingleValuePublisher<Void, E> where Element == AnySingleValuePublisher<Void, E> {
        if isEmpty {
            return Just(()).addErrorType(E.self).eraseType()
        }
        else {
            return publisher.flatMap { $0 }.last().eraseType()
        }
    }
}
