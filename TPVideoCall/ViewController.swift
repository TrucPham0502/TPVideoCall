//
//  ViewController.swift
//  TPVideoCall
//
//  Created by Truc Pham on 23/05/2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
//    private var pipController : DockableController = .init()
    private var playLayer : AAPLEAGLLayer!
    let bufferlayer = AVSampleBufferDisplayLayer()
    private lazy var previewLayer : AVCaptureVideoPreviewLayer = {
        let v = AVCaptureVideoPreviewLayer(session: session)
        v.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return v
    }()
    
    private lazy var aacPlayer : AACPlayer = {
        let v = AACPlayer()
        
        return v
    }()
    
    // MARK: Video session properties
    private let session = AVCaptureSession()
    // MARK: Video output properties
    private var videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "org.pshishkanov.videoOutputQueue")
    // MARK: audio Output propert   ies
    private let audioOutput = AVCaptureAudioDataOutput()
    private let audioOutputQueue = DispatchQueue(label: "org.pshishkanov.audioOutputQueue")
    // MARK: Coder properties
    fileprivate var videoEncoder: H265Encoder?
    fileprivate var videoDecoder: H265Decoder?
    
    fileprivate var audioEncoder: AACEncoder?
    
    // MARK: Camera devices
    private var defaultCamera: AVCaptureDevice = {
        let devices = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)!
        return devices
    }()
    
    private var defaultAudio: AVCaptureDevice = {
        let devices = AVCaptureDevice.devices(for: AVMediaType.audio) 
        return devices[0]
    }()
    var videoConnection : AVCaptureConnection?
    var audioConnection : AVCaptureConnection?
    override func viewDidLoad() {
        super.viewDidLoad()
        playLayer = AAPLEAGLLayer(frame: UIScreen.main.bounds)
        setupVideoSession()
        videoEncoder = H265Encoder(width: 200, height: 300)
        videoDecoder = H265Decoder(width: 200, height: 300)
        audioEncoder = AACEncoder()
        videoEncoder?.encodeCallbackSPSAndPPS = {vps, sps, pps in
            self.videoDecoder?.decode(data: vps)
            self.videoDecoder?.decode(data: sps)
            self.videoDecoder?.decode(data: pps)
        }
        videoEncoder?.encodeCallback = {data in
            self.videoDecoder?.decode(data: data)
        }
        videoDecoder?.decodeCallback = {pixel in
            self.playLayer.pixelBuffer = pixel
        }
        videoDecoder?.decodeWithSampeBufferCallback = {[weak self] buff in
            guard let _self = self else { return  }
            print("buffer sample: \(buff)")
//            _self.pipController.render(buff)
            _self.bufferlayer.enqueue(buff)
        }
        audioEncoder?.encodeCallback = {data in
            print("audio encode : \(data)")
//            self.aacPlayer.play(data)
        }
        
        
        self.view.layer.addSublayer(bufferlayer)
   
       
        playLayer.backgroundColor = UIColor.yellow.cgColor
        
        self.view.layer.addSublayer(previewLayer)
        // Do any additional setup after loading the view.
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.audioOutputQueue)
        if !self.session.isRunning {
            self.session.startRunning()
        }
        
//        if #available(iOS 15.0, *) {
//            let pipController = PipController(videoCallViewSourceView: self.view)
//            pipController.start()
//            videoDecoder?.decodeWithSampeBufferCallback = {[weak self] buff in
//                guard let _self = self else { return  }
//                print("buffer sample: \(buff)")
//    //            _self.pipController.render(buff)
//                pipController.sampleBufferVideoCallView.sampleBufferDisplayLayer.enqueue(buff)
//            }
//        } else {
//            // Fallback on earlier versions
//        }
        
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = .init(origin: .init(x: self.view.bounds.width - 200, y: 0), size: .init(width: 200, height: 300))
        
        bufferlayer.frame = .init(origin: .init(x: 0, y: self.view.bounds.height - 300), size: .init(width: 200, height: 300))
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
    

}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
//
//    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
//        videoEncoder?.encode(sampleBuffer)
//    }
//    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        videoEncoder?.encode(sampleBuffer)
//    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if connection == videoConnection {
            videoEncoder?.encodeVideo(sampleBuffer: sampleBuffer)
        }
        else if connection == audioConnection{
            self.audioEncoder?.encodeSampleBuffer(sampleBuffer: sampleBuffer)
        }
    }
    

}
