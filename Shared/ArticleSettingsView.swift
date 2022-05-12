//
//  ArticleSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/30/21.
//

import SwiftUI

struct ArticleSettingsConstants {
    static let minFontSize = UIDevice.current.userInterfaceIdiom == .pad ? 11 : 9
    static let maxFontSize = 30
    static let minLineHeight = 1.2
    static let maxLineHeight = 2.6
    static let minMarginWidth = 45 //%
    static let maxMarginWidth = 95 //%
}

struct ArticleSettingsView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject private var settings: Preferences
    var item: CDItem

    let buttonHeight = 25.0
    let buttonWidth = 100.0

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center) {
                HStack(spacing: 15) {
                    let isUnRead = item.unread
                    let isStarred = item.starred
                    Button {
                        Task {
                            try? await NewsManager.shared.markRead(items: [item], unread: !isUnRead)
                        }
                    } label: {
                        Label {
                            Text(isUnRead ? "Read" : "Unread")
                        } icon: {
                            Image(systemName: isUnRead ? "eye" : "eye.slash")
                        }
                        .labelStyle(.iconOnly)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    Button {
                        Task {
                            try? await NewsManager.shared.markStarred(item: item, starred: !isStarred)
                        }
                    } label: {
                        Label {
                            Text(isStarred ? "Unstar" : "Star")
                        } icon: {
                            Image(systemName: isStarred ? "star" : "star.fill")
                        }
                        .labelStyle(.iconOnly)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
                .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
                .fixedSize()
                HStack(spacing: 15) {
                    Button {
                        if settings.fontSize > ArticleSettingsConstants.minFontSize {
                            settings.fontSize -= 1
                            print("Font size \(settings.fontSize)")
                        }
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    Button {
                        if settings.fontSize < ArticleSettingsConstants.maxFontSize {
                            settings.fontSize += 1
                            print("Font size \(settings.fontSize)")
                        }
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
                .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
                .fixedSize()
                HStack(spacing: 15) {
                    Button {
                        if settings.lineHeight > ArticleSettingsConstants.minLineHeight {
                            settings.lineHeight -= 0.2
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    Button {
                        if settings.lineHeight < ArticleSettingsConstants.maxLineHeight {
                            settings.lineHeight += 0.2
                        }
                    } label: {
                        Image("custom.line.3.horizontal")
                            .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
                .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
                .fixedSize()
                HStack(spacing: 15) {
                    Button {
                        if settings.marginPortrait > ArticleSettingsConstants.minMarginWidth {
                            settings.marginPortrait -= 5
                        }
                    } label: {
                        Image(systemName: "increase.indent")
                            .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    Button {
                        if settings.marginPortrait < ArticleSettingsConstants.maxMarginWidth {
                            settings.marginPortrait += 5
                        }
                    } label: {
                        Image(systemName: "decrease.indent")
                            .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
                .padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
                .fixedSize()
            }
            .frame(width: 300)
            Spacer()
        }
    }
}

struct ArticleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleSettingsView(item: CDItem())
    }
}
