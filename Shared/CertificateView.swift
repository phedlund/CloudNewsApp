//
//  CertificateView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/28/22.
//

import SwiftUI

struct CertificateView: View {
    @Environment(\.dismiss) var dismiss
    var host: String

    @State private var content = ""

    var body: some View {
        Form {
            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Certificate")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .symbolVariant(.circle.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .accentColor(.secondary)
                }
            }
        }
        .onAppear {
            content = ServerStatus.shared.certificateText(host)
        }
    }
}

struct CertificateView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateView(host: "")
    }
}
