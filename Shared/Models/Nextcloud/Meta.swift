//
//  Meta.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/15/2023.
//  Copyright © 2023 Peter Hedlund. All rights reserved.
//

import Foundation

/*
 
 <ocs>
         <meta>
                 <status>ok</status>
                 <statuscode>100</statuscode>
                 <message>OK</message>
                 <totalitems></totalitems>
                 <itemsperpage></itemsperpage>
         </meta>
         <data>
                 <version>
                         <major>17</major>
                         <minor>0</minor>
                         <micro>2</micro>
                         <string>17.0.2</string>
                         <edition></edition>
                         <extendedSupport></extendedSupport>
                 </version>
                 <capabilities>
                         <core>
                                 <pollinterval>60</pollinterval>
                                 <webdav-root>remote.php/webdav</webdav-root>
                         </core>
                 </capabilities>
         </data>
 </ocs>
 
 */

/*
 "meta": {
     "itemsperpage": "",
     "message": "OK",
     "status": "ok",
     "statuscode": 100,
     "totalitems": ""
 }

 */
struct Meta: Codable {
    var status: String
    var statuscode: Int
    var message: String
    var totalitems: String
    var itemsperpage: String
    
    nonisolated enum CodingKeys: String, CodingKey {
        case status
        case statuscode
        case message
        case totalitems
        case itemsperpage
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        status = try values.decode(String.self, forKey: .status)
        statuscode = try values.decode(Int.self, forKey: .statuscode)
        message = try values.decode(String.self, forKey: .message)
        totalitems = try values.decode(String.self, forKey: .totalitems)
        itemsperpage = try values.decode(String.self, forKey: .itemsperpage)
    }
}
