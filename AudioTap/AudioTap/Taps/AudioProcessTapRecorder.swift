//
//  AudioProcessTapRecorder.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/17.
//

import AVFoundation
import Combine
import Foundation
import OSLog
import AppKit

// MARK: - ProcessTapRecorder

@Observable
final class AudioProcessTapRecorder {
    let fileURL: URL
    let processes: [AudioProcess]
    private let queue = DispatchQueue(label: "com.tap.audio.queue.record", qos: .userInitiated)
    private let logger: Logger

    @ObservationIgnored
    private weak var _tap: AudioProcessTap?

    private(set) var isRecording = false

    init(fileURL: URL, tap: AudioProcessTap) {
        self.processes = tap.processes
        self.fileURL = fileURL
        self._tap = tap
        self.logger = Logger(subsystem: kAppSubsystem, category: "\(String(describing: AudioProcessTapRecorder.self))(\(fileURL.lastPathComponent))")
    }

    private var tap: AudioProcessTap {
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
                // 录制存储文件到本地
                try currentFile.write(from: buffer)
                /*
                 // 存储Data回调外部使用
                 if let mdata = inInputData.pointee.mBuffers.mData {
                     let data = Data(bytes: mdata, count: Int(inInputData.pointee.mBuffers.mDataByteSize))
                     print("record buffer success:")
                 }
                 */
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
    
    @MainActor
    func open() {
        NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
    }

    private func handleInvalidation() {
        guard self.isRecording else {
            return
        }

        self.logger.debug(#function)
    }
}
