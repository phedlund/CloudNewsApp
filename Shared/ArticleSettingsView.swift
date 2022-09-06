//
//  ArticleSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/30/21.
//

import SwiftUI

struct ArticleSettingsConstants {
#if os(macOS)
    static let minFontSize = 11
#else
    static let minFontSize = UIDevice.current.userInterfaceIdiom == .pad ? 11 : 9
#endif
    static let maxFontSize = 30
    static let minLineHeight = 1.2
    static let maxLineHeight = 2.6
    static let minMarginWidth = 45 //%
    static let maxMarginWidth = 95 //%
}

struct ArticleSettingsView: View {
#if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif
    @EnvironmentObject private var settings: Preferences
    var item: CDItem

    let buttonHeight = 25.0
    let buttonWidth = 100.0

    var body: some View {
        Grid(alignment: .center, horizontalSpacing: 15, verticalSpacing: 20) {
            GridRow {
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
                            .imageScale(.large)
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                    .contentShape(Rectangle())
                }
                Button {
                    Task {
                        try? await NewsManager.shared.markStarred(item: item, starred: !isStarred)
                    }
                } label: {
                    Label {
                        Text(isStarred ? "Unstar" : "Star")
                    } icon: {
                        Image(systemName: isStarred ? "star" : "star.fill")
                            .imageScale(.large)
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                    .contentShape(Rectangle())
                }
            }
            GridRow {
                Button {
                    if settings.fontSize > ArticleSettingsConstants.minFontSize {
                        settings.fontSize -= 1
                        print("Font size \(settings.fontSize)")
                    }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if settings.fontSize < ArticleSettingsConstants.maxFontSize {
                        settings.fontSize += 1
                        print("Font size \(settings.fontSize)")
                    }
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
            }
            GridRow {
                Button {
                    if settings.lineHeight > ArticleSettingsConstants.minLineHeight {
                        settings.lineHeight -= 0.2
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if settings.lineHeight < ArticleSettingsConstants.maxLineHeight {
                        settings.lineHeight += 0.2
                    }
                } label: {
                    Image("custom.line.3.horizontal")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
            }
            GridRow {
                Button {
                    if settings.marginPortrait > ArticleSettingsConstants.minMarginWidth {
                        settings.marginPortrait -= 5
                    }
                } label: {
                    Image(systemName: "increase.indent")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if settings.marginPortrait < ArticleSettingsConstants.maxMarginWidth {
                        settings.marginPortrait += 5
                    }
                } label: {
                    Image(systemName: "decrease.indent")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
            }
        }
        .buttonStyle(.bordered)
        .padding()
    }
}

struct ArticleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleSettingsView(item: CDItem())
    }
}
