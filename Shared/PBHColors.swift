//
//  PBHColors.swift
//  iOCNews
//
//  Created by Peter Hedlund on 3/26/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Foundation
import SwiftUI

extension Color {
    static let pbh = Color.PBH()

    struct PBH {
        let whiteBackground = Color("PHWhiteBackground")
        let sepiaBackground = Color("PHSepiaBackground")
        let darkBackground = Color("PHDarkBackground")

        let whiteCellBackground = Color("PHWhiteCellBackground")
        let sepiaCellBackground = Color("PHSepiaCellBackground")
        let darkCellBackground = Color("PHDarkCellBackground")

        let whiteCellSelection = Color("PHWhiteCellSelection")
        let sepiaCellSelection = Color("PHSepiaCellSelection")
        let darkCellSelection = Color("PHDarkCellSelection")

        let whiteIcon = Color("PHWhiteIcon")
        let sepiaIcon = Color("PHSepiaIcon")
        let darkIcon = Color("PHDarkIcon")

        let whiteText = Color("PHWhiteText")
        let sepiaText = Color("PHSepiaText")
        let darkText = Color("PHDarkText")

        let whiteReadText = Color("PHWhiteReadText")
        let sepiaReadText = Color("PHSepiaReadText")
        let darkReadText = Color("PHDarkReadText")

        let whiteLink = Color("PHWhiteLink")
        let sepiaLink = Color("PHSepiaLink")
        let darkLink = Color("PHDarkLink")

        let whitePopoverBackground = Color("PHWhitePopoverBackground")
        let sepiaPopoverBackground = Color("PHSepiaPopoverBackground")
        let darkPopoverBackground = Color("PHDarkPopoverBackground")

        let whitePopoverButton = Color("PHWhitePopoverButton")
        let sepiaPopoverButton = Color("PHSepiaPopoverButton")
        let darkPopoverButton = Color("PHDarkPopoverButton")

        let whitePopoverBorder = Color("PHWhitePopoverBorder")
        let sepiaPopoverBorder = Color("PHSepiaPopoverBorder")
        let darkPopoverBorder = Color("PHDarkPopoverBorder")
    }
}

/*
@objcMembers
class ThemeColors: NSObject {

    private let backgroundColors: [Color] = [.hiteBackground, .epiaBackground, .arkBackground]
    private let cellBackgroundColors: [Color] = [.hiteCellBackground, .epiaCellBackground, .arkCellBackground]
    private let cellSelectionColors: [Color] = [.hiteCellSelection, .epiaCellSelection, .arkCellSelection]
    private let iconColors: [Color] = [.hiteIcon, .epiaIcon, .arkIcon]
    private let textColors: [Color] = [.hiteText, .epiaText, .arkText]
    private let readTextColors: [Color] = [.hiteReadText, .epiaReadText, .arkReadText]
    private let linkColors: [Color] = [.hiteLink, .epiaLink, .arkLink]
    private let popoverBackgroundColors: [Color] = [.hitePopoverBackground, .epiaPopoverBackground, .arkPopoverBackground]
    private let popoverButtonColors: [Color] = [.hitePopoverButton, .epiaPopoverButton, .arkPopoverButton]
    private let popoverBorderColors: [Color] = [.hitePopoverBorder, .epiaPopoverBorder, .arkPopoverBorder]

    lazy var ackground: Color = {
        backgroundColors[SettingsStore.theme]
    }()

    lazy var ellBackground: Color = {
        cellBackgroundColors[SettingsStore.theme]
    }()

    lazy var ellSelection: Color = {
        cellSelectionColors[SettingsStore.theme]
    }()

    lazy var con: Color = {
        iconColors[SettingsStore.theme]
    }()

    lazy var ext: Color = {
        textColors[SettingsStore.theme]
    }()

    lazy var eadText: Color = {
        readTextColors[SettingsStore.theme]
    }()

    lazy var ink: Color = {
        linkColors[SettingsStore.theme]
    }()

    lazy var opoverBackground: Color = {
        popoverBackgroundColors[SettingsStore.theme]
    }()

    lazy var opoverButton: Color = {
        popoverButtonColors[SettingsStore.theme]
    }()

    lazy var opoverBorder: Color = {
        popoverBorderColors[SettingsStore.theme]
    }()

}
*/
