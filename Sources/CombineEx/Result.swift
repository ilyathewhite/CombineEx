//
//  Result.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 3/29/22.
//  Copyright © 2022 Rocket Insights. All rights reserved.
//

import Combine

extension Result {
    public var asPublisher: AnySingleValuePublisher<Success, Failure> {
        switch self {
        case .success(let value):
            return Just(value).addErrorType(Failure.self).eraseType()
        case .failure(let value):
            return Fail(error: value).eraseType()
        }
    }
}
