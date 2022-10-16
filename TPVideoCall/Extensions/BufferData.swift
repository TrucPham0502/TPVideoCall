//
//  MessageData.swift
//  TPVideoCall
//
//  Created by Truc Pham on 12/10/2022.
//

import Foundation
enum BufferType: String, Codable {
    case audio, video, other
}

struct BufferData: Codable {
    let data: Data
    let type: BufferType
    let id : String
}

struct SignalResponse<T: Codable>: Codable {
    let id : String
    let message: String
    let resultCode: Int
    let data: T?
}

struct ClientsConnected : Codable {
    let clients : [String]
}
struct ClientsDisconnected : Codable {
}
struct Leave : Codable {
    let room: String
    let clients : [String]
}
struct Join : Codable {
    let room: String
    let clients : [String]
}


enum Request {
    case call(id: String, scrWith: Int, scrHeight: Int, encode: String, os: String)
    case join(id: String, room: String)
}
extension Request : Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "call":
            self = .call(id: try container.decode(String.self, forKey: .id), scrWith: try container.decode(Int.self, forKey: .scrWith), scrHeight: try container.decode(Int.self, forKey: .scrHeight), encode: try container.decode(String.self, forKey: CodingKeys.encode), os: try container.decode(String.self, forKey: .os))
        case "join":
            self = .join(id: try container.decode(String.self, forKey: .id), room: try container.decode(String.self, forKey: .room))
        default:
            throw DecodeError.unknownType
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .join(id, room):
            try container.encode(id, forKey: .id)
            try container.encode(room, forKey: .room)
            try container.encode("join", forKey: .type)
            
        case let .call(id,scrWith, scrHeight, encode, os):
            try container.encode(id, forKey: .id)
            try container.encode(scrWith, forKey: .scrWith)
            try container.encode(scrHeight, forKey: .scrHeight)
            try container.encode(encode, forKey: CodingKeys.encode)
            try container.encode(os, forKey: .os)
            try container.encode("call", forKey: .type)
        }
    }
    enum DecodeError: Error {
        case unknownType
    }
    enum CodingKeys: String, CodingKey {
        case id, type, room, scrWith, scrHeight, encode, os
    }
}

enum Response {
    case call(id: String, scrWith: Int, scrHeight: Int, encode: String, os: String, accept: Bool)
}
extension Response : Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "call":
            self = .call(id: try container.decode(String.self, forKey: .id), scrWith: try container.decode(Int.self, forKey: .scrWith), scrHeight: try container.decode(Int.self, forKey: .scrHeight), encode: try container.decode(String.self, forKey: CodingKeys.encode), os: try container.decode(String.self, forKey: .os), accept: try container.decode(Bool.self, forKey: .accept))
        default:
            throw DecodeError.unknownType
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .call(id, scrWith, scrHeight, encode, os, accept):
            try container.encode(id, forKey: .id)
            try container.encode(scrWith, forKey: .scrWith)
            try container.encode(scrHeight, forKey: .scrHeight)
            try container.encode(encode, forKey: CodingKeys.encode)
            try container.encode(os, forKey: .os)
            try container.encode(accept, forKey: .accept)
            try container.encode("call", forKey: .type)
        }
    }
    enum DecodeError: Error {
        case unknownType
    }
    enum CodingKeys: String, CodingKey {
        case id, type, scrWith, scrHeight, encode, os, accept
    }
}
