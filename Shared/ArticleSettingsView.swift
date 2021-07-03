//
//  ArticleSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/30/21.
//

import SwiftUI

struct ArticleSettingsView: View {
    @AppStorage(SettingKeys.fontSize) var fontSize: Int = 13
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
                    fontSize -= 1
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
                    fontSize += 1
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
                    //
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
                    //
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
                    //
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
                    //
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
