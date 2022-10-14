//
//  VideoEncoder.swift
//  TPVideoCall
//
//  Created by Truc Pham on 15/10/2022.
//

import Foundation
import VideoToolbox

protocol VideoEncoderProvider {
    var delegate : VideoEncoderDelegate? { get set }
    func setConfig(width:Int32, height:Int32, bitRate : Int32?, fps: Int32?)
    func encode(_ sampleBuffer: CMSampleBuffer)
}
extension VideoEncoderProvider {
    func setConfig(width:Int32, height:Int32) {
        self.setConfig(width: width, height: height, bitRate: nil, fps: nil)
    }
}

protocol VideoEncoderDelegate : AnyObject {
    func videoEncoder(_ encoder : VideoEncoderProvider, callback data : Data)
    func videoEncoder(_ encoder : VideoEncoderProvider, nal vps : Data?, sps: Data, pps: Data)
}
enum EncodeType : String {
    case h264, h265
    static var support : Self {
        return VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) ? .h265 : .h264
    }
}
class VideoEncoder {
    private(set) var encoder : VideoEncoderProvider
    weak var delegate : VideoEncoderDelegate? {
        didSet {
            self.encoder.delegate = delegate
        }
    }
    init(desireType: EncodeType, width:Int32, height:Int32, bitRate : Int32? = nil, fps: Int32? = nil) {
        switch desireType {
        case .h265 where EncodeType.support == .h265:
            self.encoder = H265Encoder()
        default: self.encoder = H264Encoder()
        }
        encoder.setConfig(width: width, height: height, bitRate: bitRate, fps: fps)
    }
}
