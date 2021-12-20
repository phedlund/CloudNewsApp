//
//  AppDelegate.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/18/21.
//

import BackgroundTasks
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {

    let appRefreshTaskId = "dev.pbh.cloudnews.sync"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        BGTaskScheduler.shared.register(forTaskWithIdentifier: appRefreshTaskId, using: nil) { task in
            Task {
                do {
                    //                    isSyncing = true
                    try await NewsManager().sync()
                    //                    model.update()
                    task.setTaskCompleted(success: true)
                } catch {
                    task.setTaskCompleted(success: false)
                }
                self.scheduleAppRefresh()
            }
        }

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

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshTaskId)

        request.earliestBeginDate = Date(timeIntervalSinceNow: 0) // Refresh after 5 minutes.

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Submit called")
        } catch {
            print("Could not schedule app refresh task \(error.localizedDescription)")
        }
    }

}
