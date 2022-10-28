//
//  NotificationNames.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/23/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation

extension NSNotification.Name {

    public static let syncInitiated = NSNotification.Name("SyncInitiated")
    public static let syncComplete = NSNotification.Name("SyncComplete")
    public static let loginComplete = NSNotification.Name("LoginComplete")
    public static let folderSync = NSNotification.Name("FolderSync")
    public static let feedSync = NSNotification.Name("FeedSync")
    public static let newFolder = NSNotification.Name("NewFolder")
    public static let newFeed = NSNotification.Name("NewFeed")
    public static let deleteFolder = NSNotification.Name("DeleteFolder")
    public static let renameFolder = NSNotification.Name("RenameFolder")
    public static let deleteFeed = NSNotification.Name("DeleteFeed")

}
