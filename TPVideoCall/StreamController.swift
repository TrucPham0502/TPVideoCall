//
//  StreamController.swift
//  TPVideoCall
//
//  Created by Truc Pham on 13/10/2022.
//

import Foundation
import UIKit
import AVFoundation
import WebRTC
class StreamController : UIViewController {
    enum State {
        case new, wattingAccept, joining, joined
    }
    enum CallType {
        case call(toIds: [String]), receive(fromId: String, fromSysInfo : (scrWith : Int, scrHeight : Int, encode : String, os: String))
    }
    var roomId : String = ""
    private var callIdInRoom : [String] = []
    private var callIdWattingJoinRoom : [String] = []
    private var state : State = .new
    var callType : CallType = .call(toIds: [])
    private var localViewSize : CGSize {
        return .init(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.height / 3)
    }
    private var webrtcConnected : Bool = false
    private var signalClient : SignalingClient!
    private var webRTCClient: WebRTCClient!
    // MARK: Coder properties
    fileprivate var videoEncoder: VideoEncoder!
    fileprivate var videoDecoder: VideoDecoder!
    fileprivate var audioEncoder: AACEncoder!
    
    let bufferlayer = AVSampleBufferDisplayLayer()
    private let session = AVCaptureSession()
    
    private var videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "trucpham.videoOutputQueue")
    
    private let audioOutput = AVCaptureAudioDataOutput()
    private let audioOutputQueue = DispatchQueue(label: "trucpham.audioOutputQueue")
    
    private lazy var previewLayer : AVCaptureVideoPreviewLayer = {
        let v = AVCaptureVideoPreviewLayer(session: session)
        v.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return v
    }()
    
    var videoConnection : AVCaptureConnection?
    private var defaultCamera: AVCaptureDevice = {
        let devices = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)!
        return devices
    }()
    
    var audioConnection : AVCaptureConnection?
    private var defaultAudio: AVCaptureDevice = {
        let devices = AVCaptureDevice.default(.builtInMicrophone, for: AVMediaType.audio, position: .unspecified)!
        return devices
    }()
    
    private lazy var aacPlayer : AACPlayer = {
        let v = AACPlayer()
        return v
    }()
    
    
    //MARK: View
    private lazy var localView : UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.addSublayer(previewLayer)
        return v
    }()
    
    private lazy var remoteView : UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.addSublayer(bufferlayer)
        return v
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        preapreUI()
        setupVideoSession()
        buildWebRTC()
        buildSignalingClient()
        buildAudioEncoder()
    }
    
    private func preapreUI(){
        [self.remoteView, self.localView].forEach(self.view.addSubview(_:))
        NSLayoutConstraint.activate([
            self.remoteView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.remoteView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.remoteView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.remoteView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            
            self.localView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 50),
            self.localView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24),
            self.localView.widthAnchor.constraint(equalToConstant: localViewSize.width),
            self.localView.heightAnchor.constraint(equalToConstant: localViewSize.height)
        ])
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bufferlayer.frame.size = self.remoteView.frame.size
        previewLayer.frame.size = self.localView.frame.size
    }
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.videoOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.audioOutputQueue)
        if !self.session.isRunning {
            self.session.startRunning()
        }
        handleSignalConnected()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private func handleSignalConnected(){
        if signalClient.isConnected {
            switch callType {
            case let .receive(fromId, fromSysInfo):
                self.buildVideoDecoder(desireType: .init(rawValue: fromSysInfo.encode)!)
                self.buildVideoEncoder(desireType: .init(rawValue: fromSysInfo.encode)!, width: Int32(fromSysInfo.scrWith), height: Int32(fromSysInfo.scrHeight))
                self.signalClient.sendResponseTo(response: .call(id: Config.default.id, scrWith: Int(UIScreen.main.bounds.width), scrHeight: Int(UIScreen.main.bounds.height), encode: EncodeType.support.rawValue, os: UIDevice.current.systemVersion, accept: true), sendTo: .user(id: fromId))
            case let .call(toIds):
                toIds.forEach{
                    signalClient.sendRequestTo(request: .call(id: Config.default.id,scrWith: Int(UIScreen.main.bounds.width), scrHeight: Int(UIScreen.main.bounds.height), encode: EncodeType.support.rawValue, os: UIDevice.current.systemVersion), sendTo: .user(id: $0))
                }
                self.state = .wattingAccept
            }
        }
        else { signalClient.connect() }
    }
    
    private func setupVideoSession() {
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        do {
            let videoInput = try AVCaptureDeviceInput(device: defaultCamera)
            if (session.canAddInput(videoInput)) {
                session.addInput(videoInput)
            }
            let audioInput = try AVCaptureDeviceInput(device: defaultAudio)
            if (session.canAddInput(audioInput)) {
                session.addInput(audioInput)
            }
        } catch {
            session.commitConfiguration()
            return
        }
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_32BGRA)]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            /* Setup connection orientation only after add output to session. Else connection is nil. */
            self.videoConnection = videoOutput.connection(with: .video)
            videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        }
        
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            self.audioConnection = audioOutput.connection(with: .audio)
        }
        session.commitConfiguration()
    }
    
    private func buildAudioEncoder(){
        audioEncoder = AACEncoder()
        audioEncoder!.encodeCallback = {data in
            self.webRTCClient.sendData(.init(data: data, type: .audio, id: Config.default.id))
        }
    }
    
    private func buildVideoDecoder(desireType: EncodeType){
        videoDecoder = VideoDecoder(desireType: desireType)
        videoDecoder.delegate = self
    }
    
    private func buildVideoEncoder(desireType: EncodeType,  width:Int32, height:Int32){
        videoEncoder = VideoEncoder(desireType: desireType, width: width, height: height)
        videoEncoder.delegate = self
    }
    
    private func buildWebRTC(){
        self.webRTCClient =  WebRTCClient(iceServers: Config.default.webRTCIceServers)
        self.webRTCClient.delegate = self
    }
    private func buildSignalingClient() {
        self.signalClient = .init()
        self.signalClient.delegate = self
    }
    
    func showConfirm(_ message: String , confirm :@escaping () -> (), cancel : @escaping () -> ()){
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { action in
                cancel()
            }))
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {action in
                confirm()
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
extension StreamController : WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("discovered local candidate")
        self.signalClient.send(candidate: candidate, sendTo: .user(id: client.remoteSdpForUser))
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        print("didChangeConnectionState \(state)")
        self.webrtcConnected = state == .connected
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: BufferData) {
        switch data.type {
        case .audio:
             self.aacPlayer.play(data.data)
        case .video:
            self.videoDecoder.decoder.decode(data.data)
        default: break
        }
    }
}
extension StreamController : SignalClientDelegate {
    func signalClient(_ signalClient: SignalingClient, request data: Request) {
        switch data {
        case let .join(_, room):
            self.signalClient.join(room: room)
        default: break
        }
    }
    func signalClient(_ signalClient: SignalingClient, response data: Response) {
        switch callType {
        case let .call(toIds):
            if state == .wattingAccept {
                switch data {
                case let .call(id, scrWith, scrHeight, encode, _, accept) where toIds.contains(id):
                    if accept {
                        callIdWattingJoinRoom.append(id)
                        self.buildVideoDecoder(desireType: .init(rawValue: encode)!)
                        self.buildVideoEncoder(desireType: .init(rawValue: encode)!, width: Int32(scrWith), height: Int32(scrHeight))
                        if state == .joined {
                            self.signalClient.sendRequestTo(request: .join(id: Config.default.id, room: UUID().uuidString), sendTo: .user(id: id))
                        }
                        else {
                            self.signalClient.join(room: self.roomId)
                            self.state = .joining
                        }
                    }
                    else {
                        showConfirm("\(id) not accept", confirm: {}, cancel: {})
                        self.state = .new
                    }
                default: break
                }
            }
            
        case .receive:
            break;
        }
        
    }
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        handleSignalConnected()
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        
    }
    
    func signalClient(_ signalClient: SignalingClient, join data: SignalResponse<Join>) {
        if let value = data.data {
            self.roomId = value.room
            self.callIdInRoom = value.clients.filter{ $0 != Config.default.id }
            self.callIdWattingJoinRoom.removeAll(where: {
                callIdInRoom.contains($0)
            })
        }
        if data.id == Config.default.id {
            self.state = .joined
            switch callType {
            case .call:
                self.callIdWattingJoinRoom.forEach{
                    self.signalClient.sendRequestTo(request: .join(id: Config.default.id, room: self.roomId), sendTo: .user(id: $0))
                }
            case .receive:
                self.webRTCClient.offer {[weak self] (sdp) in
                    guard let _self = self else { return }
                    _self.signalClient.send(sdp: sdp, sendTo: .room(room: _self.roomId))
                }
            }
        }
        else {
            print("Other join to room")
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: SessionDescription) {
        print("Received remote sdp")
        self.webRTCClient.set(remoteSdp: sdp.rtcSessionDescription, id: sdp.id) {[weak self] (error) in
            print("set remote sdp")
            guard let _self = self else { return }
            switch _self.callType {
            case .call:
                _self.webRTCClient.answer(completion: {[weak self] localSdp in
                    guard let _self = self else { return }
                    _self.signalClient.send(sdp: localSdp, sendTo: .user(id: sdp.id))
                })
            case .receive:
                break
            }
        }
        
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: IceCandidate) {
        self.webRTCClient.set(remoteCandidate: candidate.rtcIceCandidate) { error in
            print("set remote candidate")
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, buffer data: BufferData) {
        
    }
    
}
extension StreamController : VideoDecoderDelegate {
    func videoDecoder(_ encoder: VideoDecoderProvider, sampleBuffer data: CMSampleBuffer) {
        self.bufferlayer.enqueue(data)
    }
    func videoDecoder(_ encoder: VideoDecoderProvider, image data: CVImageBuffer) {
        //            self.playLayer.pixelBuffer = pixel
    }
}
extension StreamController : VideoEncoderDelegate {
    func videoEncoder(_ encoder: VideoEncoderProvider, callback data: Data) {
        self.webRTCClient.sendData(.init(data: data, type: .video, id: Config.default.id))
    }
    func videoEncoder(_ encoder: VideoEncoderProvider, nal vps: Data?, sps: Data, pps: Data) {
        if let vps = vps {
            self.webRTCClient.sendData(.init(data: vps, type: .video, id: Config.default.id))
        }
        self.webRTCClient.sendData(.init(data: sps, type: .video, id: Config.default.id))
        self.webRTCClient.sendData(.init(data: pps, type: .video, id: Config.default.id))
    }
}
extension StreamController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard webrtcConnected else { return }
        if connection == videoConnection {
            videoEncoder.encoder.encode(sampleBuffer)
        }
        else if connection == audioConnection{
            self.audioEncoder.encodeSampleBuffer(sampleBuffer: sampleBuffer)
        }
    }
}
