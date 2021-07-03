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
    @AppStorage(SettingKeys.fontSize) var fontSize: Int = UIDevice().userInterfaceIdiom == .pad ? 16 : 13
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait: Int = 70
    @AppStorage(SettingKeys.marginLandscape) private var marginLandscape: Int = 70
    @AppStorage(SettingKeys.lineHeight) private var lineHeight: Double = 1.4

    var body: some View {
        VStack {
            HStack {
                Button {
                    //
                } label: {
                    Image(systemName: "eye.slash")
                }
                .frame(width: 50, height: 35, alignment: .center)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 1)
                    )
                Spacer(minLength: 15)
                Button {
                    //
                } label: {
                    Image(systemName: "star")
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
        ArticleSettingsView()
    }
}
