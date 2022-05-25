//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

#if os(iOS)
import PartialSheet
#endif
import SwiftUI

@main
struct CloudNewsApp: App {
    @StateObject var settings = Preferences()
#if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    let sheetManager: PartialSheetManager = PartialSheetManager()
#endif
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
#if os(iOS)
                .environmentObject(sheetManager)
#endif
        }
    }
}
