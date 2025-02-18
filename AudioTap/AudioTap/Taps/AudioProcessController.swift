//
//  AudioProcessController.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/17.
//

import AppKit
import AudioToolbox
import Combine
import Foundation
import OSLog

// MARK: - AudioProcessController

@MainActor
@Observable
final class AudioProcessController {
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: AudioProcessController.self))

    private(set) var processes = [AudioProcess]() {
        didSet {
            guard self.processes != oldValue else {
                return
            }
            self.processGroups = AudioProcessGroup.groups(with: self.processes)
        }
    }

    /// Unused
    private(set) var processGroups = [AudioProcessGroup]()

    private var cancellables = Set<AnyCancellable>()

    func activate() {
        self.logger.debug(#function)

        NSWorkspace.shared
            .publisher(for: \.runningApplications, options: [.initial, .new])
            .map { $0.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier } }
            .sink { [weak self] apps in
                guard let self else {
                    return
                }
                self.reload(apps: apps)
            }
            .store(in: &self.cancellables)
    }

    func reload(apps: [NSRunningApplication]) {
        self.logger.debug(#function)

        do {
            let objectIdentifiers = try AudioObjectID.readProcessList()

            let updatedProcesses: [AudioProcess] = objectIdentifiers.compactMap { objectID in
                do {
                    let proc = try AudioProcess(objectID: objectID, runningApplications: apps)

                    #if DEBUG
                        if UserDefaults.standard.bool(forKey: "ACDumpProcessInfo") {
                            self.logger.debug("[PROCESS] \(String(describing: proc))")
                        }
                    #endif

                    return proc
                } catch {
                    self.logger.warning("Failed to initialize process with object ID #\(objectID, privacy: .public): \(error, privacy: .public)")
                    return nil
                }
            }

            self.processes = updatedProcesses
                .sorted { // Keep processes with audio active always on top
                    if $0.name.localizedStandardCompare($1.name) == .orderedAscending {
                        $1.audioActive && !$0.audioActive ? false : true
                    } else {
                        $0.audioActive && !$1.audioActive ? true : false
                    }
                }
        } catch {
            self.logger.error("Error reading process list: \(error, privacy: .public)")
        }
    }
}
