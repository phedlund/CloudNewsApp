//
//  ArticleSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/30/21.
//

import SwiftUI

struct ArticleSettingsView: View {
    @Environment(NewsModel.self) private var newsModel
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    @State private var item: Item?

    private let buttonHeight = 25.0
    private let buttonWidth = 100.0

    var body: some View {
        Grid(alignment: .center, horizontalSpacing: 15, verticalSpacing: 20) {
            GridRow {
                Button {
                    Task {
                        if let item {
                            newsModel.toggleItemRead(item: item)
                        }
                    }
                } label: {
                    Label {
                        Text(item?.unread ?? true ? "Read" : "Unread")
                    } icon: {
                        Image(systemName: item?.unread ?? true ? "eye" : "eye.slash")
                            .imageScale(.large)
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                    .contentShape(Rectangle())
                }
                Button {
                    Task {
                        if let item {
                            newsModel.toggleItemStarred(item: item)
                        }
                    }
                } label: {
                    Label {
                        Text(item?.starred ?? true ? "Unstar" : "Star")
                    } icon: {
                        Image(systemName: item?.starred ?? true ? "star" : "star.fill")
                            .imageScale(.large)
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                    .contentShape(Rectangle())
                }
            }
            Divider()
            GridRow {
                Button {
                    if fontSize > Constants.ArticleSettings.minFontSize {
                        fontSize -= 1
                    }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if fontSize < Constants.ArticleSettings.maxFontSize {
                        fontSize += 1
                    }
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
            }
            Divider()
            GridRow {
                Button {
                    if lineHeight > Constants.ArticleSettings.minLineHeight {
                        lineHeight -= 0.2
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if lineHeight < Constants.ArticleSettings.maxLineHeight {
                        lineHeight += 0.2
                    }
                } label: {
                    Image(.customLine3Horizontal)
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
            }
            Divider()
            GridRow {
                Button {
                    if marginPortrait > Constants.ArticleSettings.minMarginWidth {
                        marginPortrait -= 5
                    }
                } label: {
                    Image(systemName: "increase.indent")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
                Button {
                    if marginPortrait < Constants.ArticleSettings.maxMarginWidth {
                        marginPortrait += 5
                    }
                } label: {
                    Image(systemName: "decrease.indent")
                        .imageScale(.large)
                        .frame(minWidth: buttonWidth, maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight, alignment: .center)
                        .contentShape(Rectangle())
                }
            }
        }
        .accentColor(.accent)
        .buttonStyle(.bordered)
        .accentColor(.phWhiteIcon)
        .padding()
        .onAppear {
            item = newsModel.currentItem
        }
    }
}

//struct ArticleSettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticleSettingsView(item: Item())
//    }
//}
