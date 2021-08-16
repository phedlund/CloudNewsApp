//
//  ArticleSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/30/21.
//

import SwiftUI

struct ArticleSettingsConstants {
    static let minFontSize = UIDevice().userInterfaceIdiom == .pad ? 11 : 9
    static let maxFontSize = 30
    static let minLineHeight = 1.2
    static let maxLineHeight = 2.6
    static let minMarginWidth = 45 //%
    static let maxMarginWidth = 95 //%
}

struct ArticleSettingsView: View {
    @AppStorage(StorageKeys.fontSize) var fontSize: Int = UIDevice().userInterfaceIdiom == .pad ? 16 : 13
    @AppStorage(StorageKeys.marginPortrait) private var marginPortrait: Int = 70
    @AppStorage(StorageKeys.marginLandscape) private var marginLandscape: Int = 70
    @AppStorage(StorageKeys.lineHeight) private var lineHeight: Double = 1.4

    var item: CDItem

    var body: some View {
        VStack {
            HStack {
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
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
                Spacer(minLength: 15)
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
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
            HStack {
                Button {
                    if fontSize > ArticleSettingsConstants.minFontSize {
                        fontSize -= 1
                    }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
                Spacer(minLength: 30)
                Button {
                    if fontSize < ArticleSettingsConstants.maxFontSize {
                        fontSize += 1
                    }
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
            HStack {
                Button {
                    if lineHeight > ArticleSettingsConstants.minLineHeight {
                        lineHeight -= 0.2
                    }
                } label: {
                    Image("lineheight")
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
                Spacer(minLength: 30)
                Button {
                    if lineHeight < ArticleSettingsConstants.maxLineHeight {
                        lineHeight += 0.2
                    }
                } label: {
                    Image("lineheight")
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
            HStack {
                Button {
                    if marginPortrait > ArticleSettingsConstants.minMarginWidth {
                        marginPortrait -= 5
                    }
                } label: {
                    Image(systemName: "increase.indent")
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
                Spacer(minLength: 30)
                Button {
                    if marginPortrait < ArticleSettingsConstants.maxMarginWidth {
                        marginPortrait += 5
                    }
                } label: {
                    Image(systemName: "decrease.indent")
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
        }
    }
}

struct ArticleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleSettingsView(item: CDItem())
    }
}
