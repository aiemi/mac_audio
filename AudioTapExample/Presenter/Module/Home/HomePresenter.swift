//
//  HomePresenter.swift
//  AudioTapExample
//
//  Created by 大大 on 2025/2/18.
//

import AudioTap
import Combine
import Foundation

@MainActor
class HomePresenter: ObservableObject {
    func reload() {
        _ = AudioMotion.shared
    }
    
    func start() {
        AudioMotion.shared.startRecord()
    }
    
    func stop() {
        AudioMotion.shared.stopsRecord()
    }
}
