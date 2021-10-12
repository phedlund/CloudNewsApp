//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftUI

@main
struct CloudNewsApp: App {

    @StateObject var settings = Preferences()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environment(\.managedObjectContext, NewsData.mainThreadContext)
        }
    }
}
