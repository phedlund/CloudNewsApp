//
//  AppDelegate.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/18/21.
//

import BackgroundTasks
import Combine
import UserNotifications

#if os(macOS)

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private let changesPublisher = ItemStorage.shared.changes.eraseToAnyPublisher()
    private let didChangePublisher = NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: NewsData.shared.container.viewContext).eraseToAnyPublisher()

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        NewsManager.shared.syncSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let unreadCount = CDItem.unreadCount(nodeType: .all)
                self?.updateBadge(unreadCount)
            }
            .store(in: &cancellables)

        changesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let unreadCount = CDItem.unreadCount(nodeType: .all)
                self?.updateBadge(unreadCount)
            }
            .store(in: &cancellables)

        didChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let unreadCount = CDItem.unreadCount(nodeType: .all)
                self?.updateBadge(unreadCount)
            }
            .store(in: &cancellables)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound]) { granted, error in
            if error == nil {
                // success!
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func updateBadge(_ badgeValue: Int) {
        DispatchQueue.main.async {
            NSApp.dockTile.badgeLabel = badgeValue > 0 ? "\(badgeValue)" : ""
        }
    }

}

#else

import SwiftData
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        
        NewsManager.shared.syncSubject
            .receive(on: DispatchQueue.main)
            .sink { _ in
                do {
                    if let container = NewsData.shared.container {
                        let context = ModelContext(container)
                        let itemCount = try context.fetchCount(FetchDescriptor<Item>(predicate: #Predicate { $0.unread == true } ))
                        DispatchQueue.main.async {
                            UNUserNotificationCenter.current().setBadgeCount(itemCount)
                        }
                    }
                } catch { }
            }
            .store(in: &cancellables)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { granted, error in
            if error == nil {
                // success!
            }
        }

        return true
    }

}
#endif
