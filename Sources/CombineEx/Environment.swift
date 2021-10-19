//
//  Environment.swift
//  Rocket Insights
//
//  Created by Ilya Belenkiy on 3/18/21.
//  Copyright © 2021 Rocket Insights. All rights reserved.
//

import Foundation

public enum CombineEx {
    public struct Environment {
        public var logGeneralError: (Error) -> Void
        public var now: () -> Date
    }

    private static func logError(_ error: Error) {
        var errorDump = "CombineEx Error:\n"
        dump(error, to: &errorDump)
        NSLog(errorDump)
    }

    public static var env = Environment(
        logGeneralError: logError(_:),
        now: Date.init
    )
}
