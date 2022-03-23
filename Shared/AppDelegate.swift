//
//  AppDelegate.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/18/21.
//

import BackgroundTasks
import Combine
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {

    let appRefreshTaskId = "dev.pbh.cloudnews.sync"
    let appImageFetchTaskId = "dev.pbh.cloudnews.imagefetch"

    private let syncPublisher = NotificationCenter.default.publisher(for: .syncComplete, object: nil).eraseToAnyPublisher()
    private let didBecomActivePublisher = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification, object: nil).eraseToAnyPublisher()

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        
        syncPublisher
            .sink { [weak self] _ in
                let unreadCount = CDItem.unreadCount(nodeType: .all)
                self?.updateBadge(unreadCount)
            }
            .store(in: &cancellables)

        didBecomActivePublisher
            .sink { _ in
                Task {
                    do {
                        try await ItemImageFetcher().itemImages()
                    } catch {
                        print("Could not complete image fetch task \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)

    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        BGTaskScheduler.shared.register(forTaskWithIdentifier: appRefreshTaskId, using: nil) { task in
            Task {
                do {
                    try await NewsManager().sync()
                    task.setTaskCompleted(success: true)
                } catch {
                    task.setTaskCompleted(success: false)
                }
                self.scheduleAppRefresh()
            }
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: appImageFetchTaskId, using: nil) { task in
            Task {
                do {
                    try await ItemImageFetcher().itemImages()
                    task.setTaskCompleted(success: true)
                } catch {
                    task.setTaskCompleted(success: false)
                }
                self.scheduleImageFetch()
            }
        }

        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { granted, error in
            if error == nil {
                // success!
            }
        }

        return true
    }

    func updateBadge(_ badgeValue: Int) {
        print("Badge updated")
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = badgeValue
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshTaskId)

        request.earliestBeginDate = Date(timeIntervalSinceNow: .fiveMinutes)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Submit called")
        } catch {
            print("Could not schedule app refresh task \(error.localizedDescription)")
        }
    }

    func scheduleImageFetch() {
        let request = BGAppRefreshTaskRequest(identifier: appImageFetchTaskId)

        request.earliestBeginDate = Date(timeIntervalSinceNow: .fiveMinutes)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Submit called")
        } catch {
            print("Could not schedule image fetch task \(error.localizedDescription)")
        }
    }

}
