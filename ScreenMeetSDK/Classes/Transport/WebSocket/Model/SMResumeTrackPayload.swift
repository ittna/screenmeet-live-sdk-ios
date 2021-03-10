//
//  SMResumeTrackPayload.swift
//  ScreenMeet
//
//  Created by Ross on 22.01.2021.
//

import UIKit
import SocketIO

struct SMResumeTrackPayload: Codable, SocketData {
    var _target_cid: String
    var kind: String
    
    func socketRepresentation() -> SocketData {
        var data = [String: Any]()
        data["_target_cid"] = _target_cid
        data["kind"] = kind
        return data
    }
}
