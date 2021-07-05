//
//  Keychain.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/17/21.
//

import Foundation

enum StorageKeys {
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
    static let newsVersion = "newsVersion"
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
