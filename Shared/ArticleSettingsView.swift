//
//  ArticleSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/30/21.
//

import SwiftUI

struct ArticleSettingsView: View {
    private let settings =  Preferences()
    var item: CDItem

    private let buttonHeight = 25.0
    private let buttonWidth = 100.0

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
                    if settings.fontSize > Constants.ArticleSettings.minFontSize {
                        settings.fontSize -= 1
                    }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if settings.fontSize < Constants.ArticleSettings.maxFontSize {
                        settings.fontSize += 1
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
                    if settings.lineHeight > Constants.ArticleSettings.minLineHeight {
                        settings.lineHeight -= 0.2
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if settings.lineHeight < Constants.ArticleSettings.maxLineHeight {
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
                    if settings.marginPortrait > Constants.ArticleSettings.minMarginWidth {
                        settings.marginPortrait -= 5
                    }
                } label: {
                    Image(systemName: "increase.indent")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if settings.marginPortrait < Constants.ArticleSettings.maxMarginWidth {
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
