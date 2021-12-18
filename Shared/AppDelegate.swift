//
//  AppDelegate.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/18/21.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { (granted, error) in
            if error != nil {
                // success!
            }
        }

        return true
    }

    func updateBadge(_ badgeValue: Int) {
        print("Badge updated")
        UIApplication.shared.applicationIconBadgeNumber = badgeValue
    }
}
