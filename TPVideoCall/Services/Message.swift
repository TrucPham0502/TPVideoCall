//
//  Message.swift
//  WebRTC-Demo
//
//  Created by Stasel on 20/02/2019.
//  Copyright © 2019 Stasel. All rights reserved.
//

import Foundation

enum Message {
    case sdp(SessionDescription)
    case candidate(IceCandidate)
    case buffer(BufferData)
    case request(Request)
    case response(Response)
    case join(SignalResponse<Join>)
    case leave(SignalResponse<Leave>)
    case clientsConnected(SignalResponse<ClientsConnected>)
    case clientsDisconneted(SignalResponse<ClientsDisconnected>)
}

extension Message: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case String(describing: SessionDescription.self):
            self = .sdp(try container.decode(SessionDescription.self, forKey: .payload))
        case String(describing: IceCandidate.self):
            self = .candidate(try container.decode(IceCandidate.self, forKey: .payload))
        case String(describing: BufferData.self):
            self = .buffer(try container.decode(BufferData.self, forKey: .payload))
        case String(describing: Request.self):
            self = .request(try container.decode(Request.self, forKey: .payload))
        case String(describing: Response.self):
            self = .response(try container.decode(Response.self, forKey: .payload))
        case String(describing: ClientsConnected.self):
            self = .clientsConnected(try container.decode(SignalResponse<ClientsConnected>.self, forKey: .payload))
        case String(describing: Join.self):
            self = .join(try container.decode(SignalResponse<Join>.self, forKey: .payload))
        case String(describing: Leave.self):
            self = .leave(try container.decode(SignalResponse<Leave>.self, forKey: .payload))
        case String(describing: ClientsDisconnected.self):
            self = .clientsDisconneted(try container.decode(SignalResponse<ClientsDisconnected>.self, forKey: .payload))
        default:
            throw DecodeError.unknownType
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sdp(let sessionDescription):
            try container.encode(sessionDescription, forKey: .payload)
            try container.encode(String(describing: SessionDescription.self), forKey: .type)
        case .candidate(let iceCandidate):
            try container.encode(iceCandidate, forKey: .payload)
            try container.encode(String(describing: IceCandidate.self), forKey: .type)
        case .buffer(let data):
            try container.encode(data, forKey: .payload)
            try container.encode(String(describing: BufferData.self), forKey: .type)
        case .request(let data):
            try container.encode(data, forKey: .payload)
            try container.encode(String(describing: Request.self), forKey: .type)
        case .response(let data):
            try container.encode(data, forKey: .payload)
            try container.encode(String(describing: Response.self), forKey: .type)
        case .join(let data):
            try container.encode(data, forKey: .payload)
            try container.encode(String(describing: Join.self), forKey: .type)
        case .leave(let data):
            try container.encode(data, forKey: .payload)
            try container.encode(String(describing: Leave.self), forKey: .type)
        case .clientsConnected(let data):
            try container.encode(data, forKey: .payload)
            try container.encode(String(describing: ClientsConnected.self), forKey: .type)
        case .clientsDisconneted(let data):
            try container.encode(data, forKey: .payload)
            try container.encode(String(describing: ClientsDisconnected.self), forKey: .type)
        }
    }
    
    enum DecodeError: Error {
        case unknownType
    }
    
    enum CodingKeys: String, CodingKey {
        case type, payload
    }
}
