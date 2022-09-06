//
//  SyncTimer.swift
//  CloudNews (macOS)
//
//  Created by Peter Hedlund on 6/12/22.
//

import Combine
import Foundation

class SyncTimer {

    private let preferences = Preferences()

    private var timer: Timer
    private var cancellables = Set<AnyCancellable>()

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(preferences.syncInterval), repeats: true) { _ in }
        preferences.$syncInterval.sink { [weak self] interval in
            guard let self else {
                return
            }
            self.timer.invalidate()
            if self.preferences.syncInterval > 0 {
                self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.preferences.syncInterval), repeats: true) { _ in
                    Task {
                        print("Starting sync")
                        try await NewsManager.shared.sync()
                    }
                }
            }
        }
        .store(in: &cancellables)
    }
}
