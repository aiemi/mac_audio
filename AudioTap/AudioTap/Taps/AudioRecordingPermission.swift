//
//  AudioRecordingPermission.swift
//  AudioTap
//
//  Created by 大大 on 2025/2/17.
//

import Foundation
import Observation
import OSLog
import AppKit

/// Uses TCC SPI in order to check/request system audio recording permission.
@Observable
final class AudioRecordingPermission {
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: AudioRecordingPermission.self))

    enum Status: String {
        case unknown
        case denied
        case authorized
    }

    private(set) var status: Status = .unknown

    init() {
        #if ENABLE_TCC_SPI
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self else {
                    return
                }
                self.updateStatus()
            }

            self.updateStatus()
        #else
            self.status = .authorized
        #endif // ENABLE_TCC_SPI
    }

    func request() {
        #if ENABLE_TCC_SPI
            self.logger.debug(#function)

            guard let request = Self.requestSPI else {
                self.logger.fault("Request SPI missing")
                return
            }

            request("kTCCServiceAudioCapture" as CFString, nil) { [weak self] granted in
                guard let self else {
                    return
                }

                self.logger.info("Request finished with result: \(granted, privacy: .public)")

                DispatchQueue.main.async {
                    if granted {
                        self.status = .authorized
                    } else {
                        self.status = .denied
                    }
                }
            }
        #endif // ENABLE_TCC_SPI
    }

    private func updateStatus() {
        #if ENABLE_TCC_SPI
            self.logger.debug(#function)

            guard let preflight = Self.preflightSPI else {
                self.logger.fault("Preflight SPI missing")
                return
            }

            let result = preflight("kTCCServiceAudioCapture" as CFString, nil)

            if result == 1 {
                self.status = .denied
            } else if result == 0 {
                self.status = .authorized
            } else {
                self.status = .unknown
            }
        #endif // ENABLE_TCC_SPI
    }

    #if ENABLE_TCC_SPI
        private typealias PreflightFuncType = @convention(c) (CFString, CFDictionary?) -> Int
        private typealias RequestFuncType = @convention(c) (CFString, CFDictionary?, @escaping (Bool) -> Void) -> Void

        /// `dlopen` handle to the TCC framework.
        private static let apiHandle: UnsafeMutableRawPointer? = {
            let tccPath = "/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC"

            guard let handle = dlopen(tccPath, RTLD_NOW) else {
                assertionFailure("dlopen failed")
                return nil
            }

            return handle
        }()

        /// `dlsym` function handle for `TCCAccessPreflight`.
        private static let preflightSPI: PreflightFuncType? = {
            guard let apiHandle else {
                return nil
            }

            let fnName = "TCCAccessPreflight"

            guard let funcSym = dlsym(apiHandle, fnName) else {
                assertionFailure("Couldn't find symbol")
                return nil
            }

            let fn = unsafeBitCast(funcSym, to: PreflightFuncType.self)

            return fn
        }()

        /// `dlsym` function handle for `TCCAccessRequest`.
        private static let requestSPI: RequestFuncType? = {
            guard let apiHandle else {
                return nil
            }

            let fnName = "TCCAccessRequest"

            guard let funcSym = dlsym(apiHandle, fnName) else {
                assertionFailure("Couldn't find symbol")
                return nil
            }

            let fn = unsafeBitCast(funcSym, to: RequestFuncType.self)

            return fn
        }()
    #endif // ENABLE_TCC_SPI
}
