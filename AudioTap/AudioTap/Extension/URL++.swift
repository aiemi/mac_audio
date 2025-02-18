//
//  URL++.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/17.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - URL

extension URL {
    func parentBundleURL(maxDepth: Int = 8) -> URL? {
        var depth = 0
        var url = deletingLastPathComponent()
        while depth < maxDepth, !url.isBundle {
            url = url.deletingLastPathComponent()
            depth += 1
        }
        return url.isBundle ? url : nil
    }

    var isBundle: Bool {
        (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .bundle) == true
    }

    var isApp: Bool {
        (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .application) == true
    }
}

extension URL {
    static var applicationSupport: URL {
        do {
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let subdir = appSupport.appending(path: "AudioCapture", directoryHint: .isDirectory)
            if !FileManager.default.fileExists(atPath: subdir.path) {
                try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
            }
            return subdir
        } catch {
            assertionFailure("Failed to get application support directory: \(error)")

            return FileManager.default.temporaryDirectory
        }
    }
}
