//
//  VideoDecoder.swift
//  TPVideoCall
//
//  Created by Truc Pham on 15/10/2022.
//

import Foundation
import VideoToolbox
import UIKit

protocol VideoDecoderProvider {
    var delegate : VideoDecoderDelegate? { get set }
    func setConfig(width: Int32, height: Int32)
    func decode(_ data: Data)
}


protocol VideoDecoderDelegate : AnyObject {
    func videoDecoder(_ encoder : VideoDecoderProvider, image data : CVImageBuffer)
    func videoDecoder(_ encoder : VideoDecoderProvider, sampleBuffer data: CMSampleBuffer)
}

class VideoDecoder {
    private(set) var decoder : VideoDecoderProvider
    weak var delegate : VideoDecoderDelegate? {
        didSet {
            self.decoder.delegate = delegate
        }
    }
    init(desireType: EncodeType) {
        switch desireType {
        case .h265 where EncodeType.support == .h265:
            self.decoder = H265Decoder()
        default: self.decoder = H264Decoder()
        }
        decoder.setConfig(width: Int32(UIScreen.main.bounds.width), height: Int32(UIScreen.main.bounds.height))
    }
    
}
