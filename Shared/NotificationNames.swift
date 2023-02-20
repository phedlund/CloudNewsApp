//
//  NotificationNames.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/23/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation

extension NSNotification.Name {

    public static let loginComplete = NSNotification.Name("LoginComplete")
    public static let deleteFolder = NSNotification.Name("DeleteFolder")
    public static let renameFolder = NSNotification.Name("RenameFolder")
    public static let deleteFeed = NSNotification.Name("DeleteFeed")

}
