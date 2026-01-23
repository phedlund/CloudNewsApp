//
//  Errors.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/31/23.
//

import Foundation

enum DatabaseError: Error {
    case generic(message: String)
    case itemsFailedImport
    case feedsFailedImport
    case foldersFailedImport
    case failedDeletion
    case itemErrorMarkingStarred
    case itemErrorDeleting
    case feedErrorDeleting
    case folderErrorDeleting
    case nodeErrorDeleting
    case folderErrorMarkingExpanded

    public var errorDescription: String? {
        switch self {
        case .generic(message: let message):
            return NSLocalizedString(message, comment: "")
        case .itemsFailedImport:
            return NSLocalizedString("Failed to add articles to the database", comment: "")
        case .feedsFailedImport:
            return NSLocalizedString("Failed to add feeds to the database", comment: "")
        case .foldersFailedImport:
            return NSLocalizedString("Failed to add folders to the database", comment: "")
        case .failedDeletion:
            return NSLocalizedString("Failed to delete old items from database", comment: "")
        case .feedErrorDeleting:
            return NSLocalizedString("Failed to delete feed from database", comment: "")
        case .itemErrorMarkingStarred:
            return NSLocalizedString("Failed to mark article starred in database", comment: "")
        case .itemErrorDeleting:
            return NSLocalizedString("Failed to delete article from database", comment: "")
        case .folderErrorDeleting:
            return NSLocalizedString("Failed to delete folder from database", comment: "")
        case .nodeErrorDeleting:
            return NSLocalizedString("Failed to delete node from database", comment: "")
        case .folderErrorMarkingExpanded:
            return NSLocalizedString("Failed to mark folder expanded in database", comment: "")
        }
    }
}

enum NetworkError: Error {
    case generic(message: String)
    case missingUrl
    case methodNotAllowed
    case feedAlreadyExists
    case feedCouldNotBeRead
    case feedErrorAdding
    case feedDoesNotExist
    case feedErrorMoving
    case feedErrorDeleting
    case feedErrorRenaming
    case folderAlreadyExists
    case folderNameInvalid
    case folderErrorAdding
    case folderDoesNotExist
    case folderErrorRenaming
    case folderErrorDeleting
    case newsAppNeedsUpdate

    public var errorDescription: String? {
        switch self {
        case .generic(message: let message):
            return NSLocalizedString(message, comment: "")
        case .missingUrl:
            return NSLocalizedString("Missing server address", comment: "A valid server URL was missing")
        case .methodNotAllowed:
            return NSLocalizedString("Method not allowed", comment: "")
        case .feedAlreadyExists:
            return NSLocalizedString("The feed already exists", comment: "")
        case .feedCouldNotBeRead:
            return NSLocalizedString("The feed could not be read. It most likely contains errors", comment: "")
        case .feedErrorAdding:
            return NSLocalizedString("Error adding feed", comment: "")
        case .feedDoesNotExist:
            return NSLocalizedString("The feed does not exist", comment: "")
        case .feedErrorMoving:
            return NSLocalizedString("Error moving feed", comment: "")
        case .feedErrorDeleting:
            return NSLocalizedString("Error deleting feed", comment: "")
        case .feedErrorRenaming:
            return NSLocalizedString("Error renaming feed", comment: "")
        case .folderAlreadyExists:
            return NSLocalizedString("The folder already exists", comment: "")
        case .folderNameInvalid:
            return NSLocalizedString("The folder name is invalid", comment: "")
        case .folderErrorAdding:
            return NSLocalizedString("Error adding folder", comment: "")
        case .folderDoesNotExist:
            return NSLocalizedString("The folder does not exist", comment: "")
        case .folderErrorRenaming:
            return NSLocalizedString("Error renaming folder", comment: "")
        case .folderErrorDeleting:
            return NSLocalizedString("Error deleting folder", comment: "")
        case .newsAppNeedsUpdate:
            return NSLocalizedString("Please update the News app on the server to enable feed renaming", comment: "")
        }
    }

}
