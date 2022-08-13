//
//  UserDefault.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/3/21.
//

import Foundation
import Combine

@propertyWrapper
final class UserDefault<T>: NSObject {

    // This ensures requirement 1 is fulfilled. The wrapped value is stored in user defaults.
    var wrappedValue: T {
        get {
            return userDefaults.object(forKey: key) as! T
        }
        set {
            if key == StorageKeys.selectedNode {
                if let value = newValue as? String {
                    userDefaults.setValue(value, forKey: key)
                }
            } else {
                userDefaults.setValue(newValue, forKey: key)
            }
        }
    }

    var projectedValue: AnyPublisher<T, Never> {
        return subject.eraseToAnyPublisher()
    }

    private let key: String
    private let userDefaults: UserDefaults
    private var observerContext = 0
    private let subject: CurrentValueSubject<T, Never>

    init(wrappedValue defaultValue: T, _ key: String, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
        self.subject = CurrentValueSubject(defaultValue)
        super.init()
        userDefaults.register(defaults: [key: defaultValue])
        // This fulfills requirement 4. Some implementations use NSUserDefaultsDidChangeNotification
        // but that is sent every time any value is updated in UserDefaults.
        userDefaults.addObserver(self, forKeyPath: key, options: .new, context: &observerContext)
        subject.value = wrappedValue
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?) {
        if context == &observerContext {
            subject.value = wrappedValue
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    deinit {
        userDefaults.removeObserver(self, forKeyPath: key, context: &observerContext)
    }
}

// Holds a reference to all the values we store in UserDefaults. This isn't necessary but once you start
// having a lot of preferences in your app, you'll probably want to have those in a single place.
class Preferences: ObservableObject {
    @UserDefault(StorageKeys.hideRead) var hideRead = false
    @UserDefault(StorageKeys.sortOldestFirst) var sortOldestFirst = false
    @UserDefault(StorageKeys.marginPortrait) var marginPortrait = 70
    @UserDefault(StorageKeys.fontSize) var fontSize = 14
    @UserDefault(StorageKeys.lineHeight) var lineHeight = 1.4
    @UserDefault(StorageKeys.lastModified) var lastModified: Int32 = 0
    @UserDefault(StorageKeys.compactView) var compactView = false
    @UserDefault(StorageKeys.keepDuration) var keepDuration = 3
    @UserDefault(StorageKeys.syncInterval) var syncInterval = 900
    @UserDefault(StorageKeys.selectedNode) var selectedNode = AllNodeGuid
    @UserDefault(StorageKeys.selectedFeed) var selectedFeed = 0
}
