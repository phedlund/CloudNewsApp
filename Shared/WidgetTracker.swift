//
//  WidgetTracker.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/29/25.
//

import SwiftUI
import WidgetKit

final class WidgetTracker {
    @AppStorage(SettingKeys.hasWidgets) private var hasWidgets: Bool = false

    static let shared = WidgetTracker()

    private init() { }

    func detect() async {
        do {
            let currentWidgets = try await WidgetCenter.shared.currentConfigurations()
            hasWidgets = !currentWidgets.isEmpty
        } catch {
            hasWidgets = false
        }
    }

}
