//
//  DockableController.swift
//  TPVideoCall
//
//  Created by Truc Pham on 04/07/2022.
//

import Foundation
import AVKit


class SampleBufferVideoCallView: UIView {
    override class var layerClass: AnyClass {
        get { return AVSampleBufferDisplayLayer.self }
    }
    
    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }
}

class PipController {
    let sampleBufferVideoCallView = SampleBufferVideoCallView()
    var pipController : Any?
    init(videoCallViewSourceView : UIView){
        if #available(iOS 15.0, *) {
            let pipVideoCallViewController = AVPictureInPictureVideoCallViewController()
            pipVideoCallViewController.preferredContentSize = CGSize(width: 1080, height: 1920)
            pipVideoCallViewController.view.addSubview(sampleBufferVideoCallView)
            
            let pipContentSource = AVPictureInPictureController.ContentSource(
                activeVideoCallSourceView: videoCallViewSourceView,
                contentViewController: pipVideoCallViewController)
            
            pipController = AVPictureInPictureController(contentSource: pipContentSource)
            (pipController as! AVPictureInPictureController).canStartPictureInPictureAutomaticallyFromInline = true
//            pipController.delegate = self
        } else {
            // Fallback on earlier versions
        }
        

    }
    func start(){
        (pipController as? AVPictureInPictureController)?.startPictureInPicture()
    }
    func stop(){
        (pipController as? AVPictureInPictureController)?.stopPictureInPicture()
    }
}
