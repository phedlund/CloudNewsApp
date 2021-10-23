//
//  MailComposeView.swift
//  CloudNews (iOS)
//
//  Created by Peter Hedlund on 10/23/21.
//

import MessageUI
import SwiftUI

struct MailComposeView: UIViewControllerRepresentable {
    typealias UIViewControllerType = MFMailComposeViewController
    
    let recipients: [String]
    let subject: String
    let message: String
    
    var didFinish: ()->()
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<MailComposeView>) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients(recipients)
        mail.setSubject(subject)
        mail.setMessageBody(message, isHTML: false)
        return mail
    }
    
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposeView
        
        init(_ mailController: MailComposeView) {
            self.parent = mailController
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.didFinish()
            controller.dismiss(animated: true)
        }
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: UIViewControllerRepresentableContext<MailComposeView>) {
        
    }
}
