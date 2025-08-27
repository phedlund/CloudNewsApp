//
//  ValetManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/27/25.
//

import Foundation
import Valet

class ValetManager {
    static let shared = ValetManager()
    let valet = Valet.valet(with: Identifier(nonEmpty: "CloudNews")!, accessibility: .afterFirstUnlock)

    init() { }

    func saveCredentials(username: String, password: String) async throws {
        try valet.setString(username, forKey: SettingKeys.username)
        try valet.setString(password, forKey:  SettingKeys.password)
    }

    private var credentials: String {
        do {
            let username = try valet.string(forKey: SettingKeys.username)
            let password = try valet.string(forKey: SettingKeys.password)
            return Data("\(username):\(password)".utf8).base64EncodedString()
        } catch {
            print(error.localizedDescription)
        }
        return ""
    }

    var basicAuthHeader: String {
        return "Basic \(credentials)"
    }

}
