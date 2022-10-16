//
//  SignalClient.swift
//  WebRTC
//
//  Created by Stasel on 20/05/2018.
//  Copyright © 2018 Stasel. All rights reserved.
//

import Foundation
import WebRTC

protocol SignalClientDelegate: AnyObject {
    func signalClientDidConnect(_ signalClient: SignalingClient)
    func signalClientDidDisconnect(_ signalClient: SignalingClient)
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: SessionDescription)
    func signalClient(_ signalClient: SignalingClient, buffer data: BufferData)
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: IceCandidate)
    func signalClient(_ signalClient: SignalingClient, join data: SignalResponse<Join>)
    func signalClient(_ signalClient: SignalingClient, leave data: SignalResponse<Leave>)
    func signalClient(_ signalClient: SignalingClient, clientsConnected data: SignalResponse<ClientsConnected>)
    func signalClient(_ signalClient: SignalingClient, clientsDisonnected data: SignalResponse<ClientsDisconnected>)
    func signalClient(_ signalClient: SignalingClient, request data: Request)
    func signalClient(_ signalClient: SignalingClient, response data: Response)
}
extension SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient){}
    func signalClientDidDisconnect(_ signalClient: SignalingClient){}
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: SessionDescription){}
    func signalClient(_ signalClient: SignalingClient, buffer data: BufferData){}
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: IceCandidate){}
    func signalClient(_ signalClient: SignalingClient, join data: SignalResponse<Join>){}
    func signalClient(_ signalClient: SignalingClient, leave data: SignalResponse<Leave>){}
    func signalClient(_ signalClient: SignalingClient, clientsConnected data: SignalResponse<ClientsConnected>){}
    func signalClient(_ signalClient: SignalingClient, clientsDisonnected data: SignalResponse<ClientsDisconnected>){}
    func signalClient(_ signalClient: SignalingClient, request data: Request){}
    func signalClient(_ signalClient: SignalingClient, response data: Response){}
}

final class SignalingClient {
    enum SendTo {
        case room(room: String), user(id: String)
    }
    private static var _webSocketProvider : WebSocketProvider?
    private static var webSocketProvider : WebSocketProvider {
        if _webSocketProvider == nil {
            let webSocketProvider: WebSocketProvider
            if #available(iOS 13.0, *) {
                webSocketProvider = NativeWebSocket(url:  Config.default.signalingServerUrl)
            } else {
                webSocketProvider = StarscreamWebSocket(url:  Config.default.signalingServerUrl)
            }
            _webSocketProvider = webSocketProvider
        }
        return _webSocketProvider!
    }
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let webSocket: WebSocketProvider = SignalingClient.webSocketProvider
    weak var delegate: SignalClientDelegate? {
        didSet {
            self.webSocket.delegate = self
        }
    }
    var isConnected : Bool {
        self.webSocket.isConnected
    }
    
    func connect() {
        self.webSocket.connect()
    }
    
    func send(_ message : Message, sendTo: SendTo){
        let data : SignalMessage
        switch sendTo {
        case let .room(room):
            data = SignalMessage(message: message, meta: "sendRoom", room: room)
        case let .user(id):
            data = SignalMessage(message: message, meta: "send", room: id)
        }
        do {
            let dataMessage = try self.encoder.encode(data)
            self.webSocket.send(data: dataMessage)
        }
        catch {
            debugPrint("Warning: Could not encode sdp: \(error)")
        }
    }
    
    func send(sdp rtcSdp: RTCSessionDescription, sendTo: SendTo) {
        let message = Message.sdp(SessionDescription(from: rtcSdp, id: Config.default.id))
        send(message, sendTo: sendTo)
    }
    
    func send(candidate rtcIceCandidate: RTCIceCandidate, sendTo: SendTo) {
        let message =  Message.candidate(IceCandidate(from: rtcIceCandidate, id: Config.default.id))
        send(message, sendTo: sendTo)
        
    }
    
    func send(data: Data, sendTo: SendTo){
        let message = Message.buffer(.init(data: data, type: .other, id: Config.default
            .id))
        send(message, sendTo: sendTo)
    }
    
    func sendRequestTo(request: Request, sendTo : SendTo) {
        let message = Message.request(request)
        send(message, sendTo: sendTo)
    }
    func sendResponseTo(response: Response, sendTo : SendTo) {
        let message = Message.response(response)
        send(message, sendTo: sendTo)
    }
    
    func join(room: String){
        let data = SignalMessage(message: nil, meta: "join", room: room)
        do {
            let dataMessage = try self.encoder.encode(data)
            self.webSocket.send(data: dataMessage)
        }
        catch {
            debugPrint("Warning: Could not encode: \(error)")
        }
    }
    
    func leave(room: String){
        let data = SignalMessage(message: nil, meta: "leave", room: room)
        do {
            let dataMessage = try self.encoder.encode(data)
            self.webSocket.send(data: dataMessage)
        }
        catch {
            debugPrint("Warning: Could not encode: \(error)")
        }
    }
    
    func convertToObject<T : Codable>(_ message : String) -> T? {
        do {
            let people = try decoder.decode(T.self, from: message.data(using: .utf8)!)
            return people
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
}


extension SignalingClient: WebSocketProviderDelegate {
    func webSocketDidConnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalClientDidConnect(self)
    }
    
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalClientDidDisconnect(self)
        // try to reconnect every two seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            debugPrint("Trying to reconnect to signaling server...")
            self.webSocket.connect()
        }
    }
    
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data) {
        let message: Message
        do {
            message = try self.decoder.decode(Message.self, from: data)
        }
        catch {
            debugPrint("Warning: Could not decode incoming message: \(error)")
            return
        }
        switch message {
        case .candidate(let iceCandidate):
            self.delegate?.signalClient(self, didReceiveCandidate: iceCandidate)
        case .sdp(let sessionDescription):
            self.delegate?.signalClient(self, didReceiveRemoteSdp: sessionDescription)
        case .buffer(let data):
            self.delegate?.signalClient(self, buffer: data)
        case .request(let data):
            self.delegate?.signalClient(self, request: data)
        case .response(let data):
            self.delegate?.signalClient(self, response: data)
        case .clientsConnected(let data):
            self.delegate?.signalClient(self, clientsConnected: data)
        case .join(let data):
            self.delegate?.signalClient(self, join: data)
        case .leave(let data):
            self.delegate?.signalClient(self, leave: data)
        case .clientsDisconneted(let data):
            self.delegate?.signalClient(self, clientsDisonnected: data)
        }

    }
}
