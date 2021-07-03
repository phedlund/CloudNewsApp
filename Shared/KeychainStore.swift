//
//  Keychain.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/17/21.
//

import Foundation
import KeychainAccess

enum SettingKeys {
    static let username = "username"
    static let password = "password"
    static let server = "Server"
    static let version = "version"
    static let syncOnStart = "SyncOnStart"
    static let offlineMode = "OfflineMode"
    static let isLoggedIn = "LoggedIn"
    static let allowUntrustedCertificate = "AllowUntrustedCertificate"
    static let dbReset = "dbReset"
    static let didSyncInBackground = "didSyncInBackground"
    static let notesApiVersion = "notesApiVersion"
    static let notesVersion = "notesVersion"
    static let productVersion = "productVersion"
    static let productName = "productName"
    static let eTag = "eTag"
    static let lastModified = "lastModified"
    static let category = "category"
    static let selectedCategory = "SelectedCategory"
    static let compactView = "CompactView"
    static let showThumbnails = "ShowThumbnails"
    static let fontSize = "FontSize"
    static let marginPortrait = "MarginPortrait"
    static let marginLandscape = "MarginLandscape"
    static let lineHeight = "LineHeight"
}

@propertyWrapper struct KeychainBacked<String> {
    let key: String
    let defaultValue: String
    var storage = Keychain(service: "com.peterandlinda.CloudNews")

    var wrappedValue: String {
        get {
            let value = storage["\(key)"] as? String
            return value ?? defaultValue
        }
        set {
            storage["\(key)"] = (newValue as! Swift.String)
        }
    }
}

class KeychainStore: ObservableObject {

    @KeychainBacked(key: SettingKeys.username, defaultValue: "")
    var username: String

    @KeychainBacked(key: SettingKeys.password, defaultValue: "")
    var password: String

}
