//
//  Config.swift
//  TPVideoCall
//
//  Created by Truc Pham on 12/10/2022.
//

import Foundation

// Set this to the machine's address which runs the signaling server. Do not use 'localhost' or '127.0.0.1'
fileprivate let uuid : String = UUID().uuidString
fileprivate let defaultSignalingServerUrl = URL(string: "ws://192.168.1.7:8080?userId=\(uuid)")!

// We use Google's public stun servers. For production apps you should deploy your own stun/turn servers.
fileprivate let defaultIceServers = ["stun:stun.l.google.com:19302",
                                     "stun:stun1.l.google.com:19302",
                                     "stun:stun2.l.google.com:19302",
                                     "stun:stun3.l.google.com:19302",
                                     "stun:stun4.l.google.com:19302"]

struct Config {
    let id : String
    let signalingServerUrl: URL
    let webRTCIceServers: [String]
    
    static let `default` = Config(id: uuid, signalingServerUrl: defaultSignalingServerUrl, webRTCIceServers: defaultIceServers)
}
