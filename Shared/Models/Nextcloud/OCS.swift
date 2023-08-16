//
//  OCS.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/15/2023.
//  Copyright © 2023 Peter Hedlund. All rights reserved.
//

import Foundation

struct OCS: Decodable {
    var meta: Meta
    var data: Data
    
    enum OCSKeys: String, CodingKey {
        case meta
        case data
    }
    
    enum CodingKeys: String, CodingKey {
        case ocs
    }

    init(from decoder: Decoder) throws {
        // Extract the top-level values ("ocs")
        let values = try decoder.container(keyedBy: CodingKeys.self)

        // Extract the user object as a nested container
        let ocs = try values.nestedContainer(keyedBy: OCSKeys.self, forKey: .ocs)

        // Extract each property from the nested container
        meta = try ocs.decode(Meta.self, forKey: .meta)
        data = try ocs.decode(Data.self, forKey: .data)
    }

}
