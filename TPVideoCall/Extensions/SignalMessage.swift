//
//  SignalMessage.swift
//  TPVideoCall
//
//  Created by Truc Pham on 13/10/2022.
//

import Foundation
struct SignalMessage : Codable {
    let message : Message?
    let meta : String
    let room : String
}
