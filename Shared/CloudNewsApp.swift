//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import PartialSheet
import SwiftUI

@main
struct CloudNewsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var settings = Preferences()
    let sheetManager: PartialSheetManager = PartialSheetManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(sheetManager)
                .environment(\.managedObjectContext, NewsData.mainThreadContext)
        }
    }
}
