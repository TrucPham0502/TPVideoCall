//
//  H264Encoder.swift
//  TPVideoCall
//
//  Created by Truc Pham on 25/05/2022.
//

import Foundation
import VideoToolbox
class H264Encoder : VideoEncoderProvider {
    weak var delegate : VideoEncoderDelegate?
    private var frameID:Int64 = 0
    private var hasSpsPps = false
    private var width: Int32 = 1920
    private var height:Int32 = 1080
    private var bitRate : Int32 = 1920 * 1080 * 3 * 4
    private var fps : Int32 = 60
    private var encodeQueue = DispatchQueue(label: "encode")
    private var callBackQueue = DispatchQueue(label: "callBack")
    
    private var encodeSession:VTCompressionSession!
    private var encodeCallBack:VTCompressionOutputCallback?

    
    init() {
        setCallBack()
        initVideoToolBox()
    }
    
    func setConfig(width:Int32, height:Int32, bitRate : Int32?, fps: Int32?){
        self.width = width
        self.height = height
        self.bitRate = bitRate != nil ? bitRate! : width * height * 3 * 4
        self.fps = (fps != nil) ? fps! : 60
        setCallBack()
        initVideoToolBox()
    }
    
    private func initVideoToolBox() {
        print(self)
        //create VTCompressionSession
        let state = VTCompressionSessionCreate(allocator: kCFAllocatorDefault, width: width, height: height, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback:encodeCallBack , refcon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self), compressionSessionOut: &self.encodeSession)
        
        if state != noErr {
            print("creat VTCompressionSession failed")
            return
        }
        
        //Set real-time encoding output
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        //Set encoding method
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        //Set whether to generate B frames (because B frames are not necessary when decoding, B frames can be discarded)
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        //Set key frame interval
        var frameInterval = 10
        let number = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &frameInterval)
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: number)
        
        //Set the desired frame rate, not the actual frame rate
        let fpscf = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &fps)
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fpscf)
        
        //Set the average bit rate, the unit is bps. If the bit rate is higher, it will be very clear, but at the same time the file will be larger. If the bit rate is small, the image will sometimes be blurred, but it can barely be seen
        //Code rate calculation formula reference notes
        //        var bitrate = width * height * 3 * 4
        let bitrateAverage = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &bitRate)
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrateAverage)
        
        //Bit rate limit
        let bitRatesLimit :CFArray = [bitRate * 2,1] as CFArray
        VTSessionSetProperty(encodeSession, key: kVTCompressionPropertyKey_DataRateLimits, value: bitRatesLimit)
    }
    
    private func setCallBack()  {
        //Coding complete callback
        encodeCallBack = {(outputCallbackRefCon, sourceFrameRefCon, status, flag, sampleBuffer)  in
            
            let encoder : H264Encoder = unsafeBitCast(outputCallbackRefCon, to: H264Encoder.self)
            
            guard let sampleBuffer = sampleBuffer else {
                return
            }
            
            
            /// 0. Raw byte data 8 bytes
            let buffer : [UInt8] = [0x00,0x00,0x00,0x01]
            /// 1. [UInt8] -> UnsafeBufferPointer<UInt8>
            let unsafeBufferPointer = buffer.withUnsafeBufferPointer {$0}
            /// 2.. UnsafeBufferPointer<UInt8> -> UnsafePointer<UInt8>
            let  unsafePointer = unsafeBufferPointer.baseAddress
            guard let startCode = unsafePointer else {return}
            
            let attachArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
            
            
            let strkey = unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self)
            let cfDic = unsafeBitCast(CFArrayGetValueAtIndex(attachArray, 0), to: CFDictionary.self)
            let keyFrame = !CFDictionaryContainsKey(cfDic, strkey)//Without this key, it means synchronization, which is a key frame
            
            //  Obtain sps pps
            if keyFrame && !encoder.hasSpsPps{
                if let description = CMSampleBufferGetFormatDescription(sampleBuffer){
                    var spsSize: Int = 0, spsCount :Int = 0,spsHeaderLength:Int32 = 0
                    var ppsSize: Int = 0, ppsCount: Int = 0,ppsHeaderLength:Int32 = 0
                    //var spsData:UInt8 = 0, ppsData:UInt8 = 0
                    
                    var spsDataPointer : UnsafePointer<UInt8>? = UnsafePointer(UnsafeMutablePointer<UInt8>.allocate(capacity: 0))
                    var ppsDataPointer : UnsafePointer<UInt8>? = UnsafePointer<UInt8>(bitPattern: 0)
                    let spsstatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, parameterSetIndex: 0, parameterSetPointerOut: &spsDataPointer, parameterSetSizeOut: &spsSize, parameterSetCountOut: &spsCount, nalUnitHeaderLengthOut: &spsHeaderLength)
                    if spsstatus != noErr{
                        print("sps fail")
                    }
                    
                    let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, parameterSetIndex: 1, parameterSetPointerOut: &ppsDataPointer, parameterSetSizeOut: &ppsSize, parameterSetCountOut: &ppsCount, nalUnitHeaderLengthOut: &ppsHeaderLength)
                    if ppsStatus != noErr {
                        print("pps fail")
                    }
                   
                    
                    if let spsData = spsDataPointer,let ppsData = ppsDataPointer{
                        encoder.hasSpsPps = true
                        var spsDataValue = Data(capacity: 4 + spsSize)
                        spsDataValue.append(buffer, count: 4)
                        spsDataValue.append(spsData, count: spsSize)
                        
                        var ppsDataValue = Data(capacity: 4 + ppsSize)
                        ppsDataValue.append(startCode, count: 4)
                        ppsDataValue.append(ppsData, count: ppsSize)
                        encoder.callBackQueue.async {
                            encoder.delegate?.videoEncoder(encoder, nal: nil, sps: spsDataValue, pps: ppsDataValue)
                        }
                    }
                }
            }
            
            
            // --------- data input ----------
            let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
            //var arr = [Int8]()
            //let pointer = arr.withUnsafeMutableBufferPointer({$0})
            var dataPointer: UnsafeMutablePointer<Int8>?  = nil
            var totalLength :Int = 0
            let blockState = CMBlockBufferGetDataPointer(dataBuffer!, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
            if blockState != noErr{
                print("Failed to get data\(blockState)")
            }
            
            //NALU
            var offset :UInt32 = 0
            //The first four bytes of the returned nalu data are not the startcode of 0001 (not the 0001 of the system side), but the frame length of the big-endian mode.
            let lengthInfoSize = 4
            //Write nalu data cyclically
            while offset < totalLength - lengthInfoSize {
                //Get nalu data length
                var naluDataLength:UInt32 = 0
                memcpy(&naluDataLength, dataPointer! + UnsafeMutablePointer<Int8>.Stride(offset), lengthInfoSize)
                //Big endian to system end
                naluDataLength = CFSwapInt32BigToHost(naluDataLength)
                //Get the encoded video data
                var data = Data(capacity: Int(naluDataLength) + lengthInfoSize)
                data.append(buffer, count: 4)
                //Transform pointer；UnsafeMutablePointer<Int8> -> UnsafePointer<UInt8>
                let naluUnsafePoint = unsafeBitCast(dataPointer, to: UnsafePointer<UInt8>.self)

                data.append(naluUnsafePoint + UnsafePointer<UInt8>.Stride(offset + UInt32(lengthInfoSize)) , count: Int(naluDataLength))
                
                encoder.callBackQueue.async {
                    encoder.delegate?.videoEncoder(encoder, callback: data)
                }
                offset += (naluDataLength + UInt32(lengthInfoSize))
                
            }
        }
    }
    
    //Start coding
    func encode(_ sampleBuffer:CMSampleBuffer){
        if self.encodeSession == nil {
            initVideoToolBox()
        }
        encodeQueue.async {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//            let duration = CMSampleBufferGetDuration(sampleBuffer)
//            let time = CMTime(value: self.frameID, timescale: 10000)
            var flags: VTEncodeInfoFlags = VTEncodeInfoFlags()
            let state = VTCompressionSessionEncodeFrame(self.encodeSession, imageBuffer: imageBuffer, presentationTimeStamp: .invalid, duration: .invalid, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: &flags)
            if state != noErr{
                print("encode filure")
            }
        }
        
    }
    
    deinit {
        if ((encodeSession) != nil) {
            VTCompressionSessionCompleteFrames(encodeSession, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(encodeSession);
            encodeSession = nil;
        }
    }
}
