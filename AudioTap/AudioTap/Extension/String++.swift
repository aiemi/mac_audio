//
//  String++.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/17.
//

import Foundation

// MARK: - String + LocalizedError

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}

// MARK: - String + lastReverseDNSComponent

extension String {
    var lastReverseDNSComponent: String? {
        components(separatedBy: ".").last.flatMap { $0.isEmpty ? nil : $0 }
    }
}
