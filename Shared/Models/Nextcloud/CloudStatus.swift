//
//  Status.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/15/2023.
//  Copyright © 2023 Peter Hedlund. All rights reserved.
//

import Foundation

/*
 {"installed":true,
 "maintenance":false,
 "needsDbUpgrade":false,
 "version":"10.0.10.4",
 "versionstring":"10.0.10",
 "edition":"Community",
 "productname":"ownCloud"
 }
 */

struct CloudStatus: Decodable {
    var installed: Bool
    var maintenance: Bool
    var needsDbUpgrade: Bool
    var version: String
    var versionstring: String
    var edition: String
    var productname: String
    
    enum CodingKeys: String, CodingKey {
        case installed
        case maintenance
        case needsDbUpgrade
        case version
        case versionstring
        case edition
        case productname
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        installed = try values.decode(Bool.self, forKey: .installed)
        maintenance = try values.decode(Bool.self, forKey: .maintenance)
        needsDbUpgrade = try values.decode(Bool.self, forKey: .needsDbUpgrade)
        version = try values.decode(String.self, forKey: .version)
        versionstring = try values.decode(String.self, forKey: .versionstring)
        edition = try values.decode(String.self, forKey: .edition)
        productname = try values.decode(String.self, forKey: .productname)
    }

}
