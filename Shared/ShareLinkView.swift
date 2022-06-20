//
//  ShareLinkView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/22.
//

import SwiftUI

struct ShareLinkView: View {
    var model: ArticleModel?

    private var url: URL?
    private var subject = ""
    private var message = ""

    init(model: ArticleModel?) {
        self.model = model
        if let model {
            url = model.webView.url
            subject = model.webView.title ?? ""
            if url?.scheme?.hasPrefix("file") ?? false {
                if let urlString = model.item?.url {
                    url = URL(string: urlString) ?? nil
                    subject = model.item?.title ?? "Untitled"
                    message = model.item?.displayBody ?? ""
                }
            }
        }
    }

    @ViewBuilder
    var body: some View {
        if let url {
            ShareLink(item: url, subject: Text(subject), message: Text(message))
        } else if !subject.isEmpty {
            ShareLink(item: subject, subject: Text(subject), message: Text(message))
        } else {
            EmptyView()
        }
    }
}

//struct ShareLinkView_Previews: PreviewProvider {
//    static var previews: some View {
//        ShareLinkView()
//    }
//}
