//
//  NSWorkspace.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/18.
//

import AppKit
import Foundation

extension NSWorkspace {
    
    /// Call open system setting
    /// eg: NSWorkspace.shared.openSystemSettings()
    func openSystemSettings() {
        guard let url = urlForApplication(withBundleIdentifier: "com.apple.systempreferences") else {
            assertionFailure("Failed to get System Settings app URL")
            return
        }

        openApplication(at: url, configuration: .init())
    }
}
