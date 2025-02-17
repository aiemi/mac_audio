//
//  AudioProcessTap.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/17.
//

import AudioToolbox
import AVFoundation
import Foundation
import OSLog
import SwiftUI

// MARK: - ProcessTap

@Observable
final class ProcessTap {
    typealias InvalidationHandler = (ProcessTap) -> Void

    let processes: [AudioProcess]
    let muteWhenRunning: Bool
    private let logger: Logger

    private(set) var errorMessage: String?

    init(processes: [AudioProcess], muteWhenRunning: Bool = false) {
        self.processes = processes
        self.muteWhenRunning = muteWhenRunning
        self.logger = Logger(subsystem: kAppSubsystem, category: "\(String(describing: ProcessTap.self))(\(processes.description))")
    }

    @ObservationIgnored
    private var processTapID: AudioObjectID = .unknown
    @ObservationIgnored
    private var aggregateDeviceID = AudioObjectID.unknown
    @ObservationIgnored
    private var deviceProcID: AudioDeviceIOProcID?
    @ObservationIgnored
    private(set) var tapStreamDescription: AudioStreamBasicDescription?
    @ObservationIgnored
    private var invalidationHandler: InvalidationHandler?

    @ObservationIgnored
    private(set) var activated = false

    @MainActor
    func activate() {
        guard !self.activated else {
            return
        }
        self.activated = true

        self.logger.debug(#function)

        self.errorMessage = nil

        let audioObjectIds = self.processes.map { $0.objectID }
        do {
            try self.prepare(for: audioObjectIds)
        } catch {
            self.logger.error("\(error, privacy: .public)")
            self.errorMessage = error.localizedDescription
        }
    }

    func invalidate() {
        guard self.activated else {
            return
        }
        defer { activated = false }

        self.logger.debug(#function)

        self.invalidationHandler?(self)
        self.invalidationHandler = nil

        if self.aggregateDeviceID.isValid {
            var err = AudioDeviceStop(aggregateDeviceID, deviceProcID)
            if err != noErr {
                self.logger.warning("Failed to stop aggregate device: \(err, privacy: .public)")
            }

            if let deviceProcID {
                err = AudioDeviceDestroyIOProcID(self.aggregateDeviceID, deviceProcID)
                if err != noErr {
                    self.logger.warning("Failed to destroy device I/O proc: \(err, privacy: .public)")
                }
                self.deviceProcID = nil
            }

            err = AudioHardwareDestroyAggregateDevice(self.aggregateDeviceID)
            if err != noErr {
                self.logger.warning("Failed to destroy aggregate device: \(err, privacy: .public)")
            }
            self.aggregateDeviceID = .unknown
        }

        if self.processTapID.isValid {
            let err = AudioHardwareDestroyProcessTap(processTapID)
            if err != noErr {
                self.logger.warning("Failed to destroy audio tap: \(err, privacy: .public)")
            }
            self.processTapID = .unknown
        }
    }

    private func prepare(for objectIDs: [AudioObjectID]) throws {
        self.errorMessage = nil

        let tapDescription = CATapDescription(stereoMixdownOfProcesses: objectIDs)
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = self.muteWhenRunning ? .mutedWhenTapped : .unmuted
        var tapID: AUAudioObjectID = .unknown
        var err = AudioHardwareCreateProcessTap(tapDescription, &tapID)

        guard err == noErr else {
            self.errorMessage = "Process tap creation failed with error \(err)"
            return
        }

        self.logger.debug("Created process tap #\(tapID, privacy: .public)")

        self.processTapID = tapID

        let systemOutputID = try AudioDeviceID.readDefaultSystemOutputDevice()

        let outputUID = try systemOutputID.readDeviceUID()

        let aggregateUID = UUID().uuidString

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Tap-\(objectIDs.count)",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [
                    kAudioSubDeviceUIDKey: outputUID,
                ],
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
                ],
            ],
        ]

        self.tapStreamDescription = try tapID.readAudioTapStreamBasicDescription()

        self.aggregateDeviceID = AudioObjectID.unknown
        err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &self.aggregateDeviceID)
        guard err == noErr else {
            throw "Failed to create aggregate device: \(err)"
        }

        self.logger.debug("Created aggregate device #\(self.aggregateDeviceID, privacy: .public)")
    }

    func run(on queue: DispatchQueue, ioBlock: @escaping AudioDeviceIOBlock, invalidationHandler: @escaping InvalidationHandler) throws {
        assert(self.activated, "\(#function) called with inactive tap!")
        assert(self.invalidationHandler == nil, "\(#function) called with tap already active!")

        self.errorMessage = nil

        self.logger.debug("Run tap!")

        self.invalidationHandler = invalidationHandler

        var err = AudioDeviceCreateIOProcIDWithBlock(&self.deviceProcID, self.aggregateDeviceID, queue, ioBlock)
        guard err == noErr else {
            throw "Failed to create device I/O proc: \(err)"
        }

        err = AudioDeviceStart(self.aggregateDeviceID, self.deviceProcID)
        guard err == noErr else {
            throw "Failed to start audio device: \(err)"
        }
    }

    deinit { invalidate() }
}

// MARK: - ProcessTapRecorder

@Observable
final class ProcessTapRecorder {
    let fileURL: URL
    let processes: [AudioProcess]
    private let queue = DispatchQueue(label: "ProcessTapRecorder", qos: .userInitiated)
    private let logger: Logger

    @ObservationIgnored
    private weak var _tap: ProcessTap?

    private(set) var isRecording = false

    init(fileURL: URL, tap: ProcessTap) {
        self.processes = tap.processes
        self.fileURL = fileURL
        self._tap = tap
        self.logger = Logger(subsystem: kAppSubsystem, category: "\(String(describing: ProcessTapRecorder.self))(\(fileURL.lastPathComponent))")
    }

    private var tap: ProcessTap {
        get throws {
            guard let _tap else {
                throw "Process tab unavailable"
            }
            return _tap
        }
    }

    @ObservationIgnored
    private var currentFile: AVAudioFile?

    @MainActor
    func start() throws {
        self.logger.debug(#function)

        guard !self.isRecording else {
            self.logger.warning("\(#function, privacy: .public) while already recording")
            return
        }

        let tap = try tap

        if !tap.activated {
            tap.activate()
        }

        guard var streamDescription = tap.tapStreamDescription else {
            throw "Tap stream description not available."
        }

        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw "Failed to create AVAudioFormat."
        }

        self.logger.info("Using audio format: \(format, privacy: .public)")

        let settings: [String: Any] = [
            AVFormatIDKey: streamDescription.mFormatID,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
        ]
        let file = try AVAudioFile(forWriting: fileURL, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: format.isInterleaved)

        self.currentFile = file

        try tap.run(on: self.queue) { [weak self] inNow, inInputData, inInputTime, outOutputData, inOutputTime in
            guard let self, let currentFile = self.currentFile else {
                return
            }
            do {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inInputData, deallocator: nil) else {
                    throw "Failed to create PCM buffer"
                }

                try currentFile.write(from: buffer)
            } catch {
                self.logger.error("\(error, privacy: .public)")
            }
        } invalidationHandler: { [weak self] tap in
            guard let self else {
                return
            }
            self.handleInvalidation()
        }

        self.isRecording = true
    }

    func stop() {
        do {
            self.logger.debug(#function)

            guard self.isRecording else {
                return
            }

            self.currentFile = nil

            self.isRecording = false

            try self.tap.invalidate()
        } catch {
            self.logger.error("Stop failed: \(error, privacy: .public)")
        }
    }

    private func handleInvalidation() {
        guard self.isRecording else {
            return
        }

        self.logger.debug(#function)
    }
}
