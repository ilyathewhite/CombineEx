//
//  CombineLatestMany.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 3/14/22.
//  Copyright © 2022 Rocket Insights. All rights reserved.
//

import Foundation
import Combine

public func combineLatestMany<A, E: Error, S: Collection>(_ publishers: S) -> AnyPublisher<[A], E>
where S.Element == AnyPublisher<A, E>
{
    guard let first = publishers.first else {
        return Just([]).addErrorType(E.self).eraseToAnyPublisher()
    }

    let other = combineLatestMany(publishers.dropFirst())
    return first.combineLatest(other).map { [$0.0] + $0.1 }.eraseToAnyPublisher()
}
