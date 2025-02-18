//
//  AudioMotion.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/18.
//

import AppKit
import Combine
import Foundation
import SwiftUICore

// MARK: - AudioCaptureDelegate

@objc public protocol AudioCaptureDelegate {
    func receiveAudioData(_ data: Data)
}

// MARK: - AudioMotion

@MainActor
public final class AudioMotion: NSObject {
    // MARK: - Lifecycle
    
    public static let shared = AudioMotion()

    override public init() {
        super.init()

        self.config()
    }

    // MARK: - Properties
    
    @objc public var delegate: AudioCaptureDelegate?
    
    // @StateObject
    @State private var permission = AudioRecordingPermission()
    // @StateObject
    @State private var processController = AudioProcessController()
    
    // MARK: - Methods
    
    private var cancellable: AnyCancellable?
    
    private func config() {
        if !self.processController.processes.isEmpty {
            print("processController.processes update: \(self.processController.processes.count)")
        }
        
        switch self.permission.status {
        case .unknown:
            print("audio permission request")
            self.permission.request()
        case .authorized:
            print("audio permission authorized")
            self.processController.activate()
        case .denied:
            print("audio permission denied, start system")
            NSWorkspace.shared.openSystemSettings()
        }
    }
}

public extension AudioMotion {
    func startRecordingTest() {
        let data = Data()
        self.delegate?.receiveAudioData(data)
    }
}

