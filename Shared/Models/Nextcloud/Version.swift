//
//  Version.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/15/2023.
//  Copyright © 2023 Peter Hedlund. All rights reserved.
//

import Foundation

/*
 "version": {
     "edition": "",
     "extendedSupport": 0,
     "major": 18,
     "micro": 2,
     "minor": 0,
     "string": "18.0.2"
 }

 */
struct Version: Codable {
    var major: Int
    var minor: Int
    var micro: Int
    var string: String
    var edition: String
    var extendedSupport: Bool
    
    enum CodingKeys: String, CodingKey {
        case major
        case minor
        case micro
        case string
        case edition
        case extendedSupport
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        major = try values.decode(Int.self, forKey: .major)
        minor = try values.decode(Int.self, forKey: .minor)
        micro = try values.decode(Int.self, forKey: .micro)
        string = try values.decode(String.self, forKey: .string)
        edition = try values.decode(String.self, forKey: .edition)
        extendedSupport = try values.decodeIfPresent(Bool.self, forKey: .extendedSupport) ?? false
    }
}
