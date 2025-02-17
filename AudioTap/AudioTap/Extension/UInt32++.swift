//
//  UInt32++.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/17.
//

import Foundation

// MARK: - UInt32 + fourCharString

extension UInt32 {
    var fourCharString: String {
        String(cString: [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF),
            0,
        ])
    }
}
