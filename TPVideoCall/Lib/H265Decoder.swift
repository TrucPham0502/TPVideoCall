//
//  H265Decoder.swift
//  TPVideoCall
//
//  Created by Truc Pham on 25/05/2022.
//

import Foundation
import VideoToolbox
class H265Decoder {
    var width: Int32 = 1920
    var height:Int32 = 1080
    
    var decodeQueue = DispatchQueue(label: "decode")
    var callBackQueue = DispatchQueue(label: "decodeCallBack")
    var decodeDesc : CMVideoFormatDescription?
    
    var spsData:Data?
    var ppsData:Data?
    var vpsData:Data?
    
    var decompressionSession : VTDecompressionSession?
    var callback : VTDecompressionOutputCallback?
    
    var decodeCallback:((CVImageBuffer?) -> Void)?
    
    var decodeWithSampeBufferCallback:((CMSampleBuffer) -> Void)?
    
    init(width:Int32 = 1920,height:Int32 = 1080) {
        self.width = width
        self.height = height
    }
    
    func initDecoder() -> Bool {
        
        if decompressionSession != nil {
            return true
        }
        guard spsData != nil,ppsData != nil, vpsData != nil else {
            return false
        }
        //var frameData = Data(capacity: Int(size))
        //frameData.append(length, count: 4)
        //let point :UnsafePointer<UInt8> = [UInt8](data).withUnsafeBufferPointer({$0}).baseAddress!
        //frameData.append(point + UnsafePointer<UInt8>.Stride(4), count: Int(naluSize))
        //Processing sps/pps
        var vps : [UInt8] = []
        [UInt8](vpsData!).suffix(from: 4).forEach { (value) in
            vps.append(value)
        }
        
        var sps : [UInt8] = []
        [UInt8](spsData!).suffix(from: 4).forEach { (value) in
            sps.append(value)
        }
        
        var pps : [UInt8] = []
        [UInt8](ppsData!).suffix(from: 4).forEach{(value) in
            pps.append(value)
        }
        
        let vpsSpsAndpps = [vps.withUnsafeBufferPointer{$0}.baseAddress!, sps.withUnsafeBufferPointer{$0}.baseAddress!, pps.withUnsafeBufferPointer{$0}.baseAddress!]
        let sizes = [vps.count ,sps.count,pps.count]
        
        /**
         Set decoding parameters according to sps pps
         param kCFAllocatorDefault allocator
         param 2 Number of parameters
         param parameterSetPointers parameter set pointers
         param parameterSetSizes parameter set size
         length of param naluHeaderLen nalu nalu start code 4
         param _decodeDesc Decoder description
         return status
         */
        let descriptionState = CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: kCFAllocatorDefault, parameterSetCount: vpsSpsAndpps.count, parameterSetPointers: vpsSpsAndpps, parameterSetSizes: sizes, nalUnitHeaderLength: 4, extensions: nil, formatDescriptionOut: &decodeDesc)
        if descriptionState != noErr {
            print("Description creation failed" )
            return false
        }
        //Decoding callback setting
        /*
         VTDecompressionOutputCallbackRecord is a simple structure with a pointer (decompressionOutputCallback) to the callback method after the frame is decompressed. You need to provide an instance (decompressionOutputRefCon) where this callback method can be found. The VTDecompressionOutputCallback callback method includes seven parameters:
         Parameter 1: Reference of the callback
         Parameter 2: Reference of the frame
         Parameter 3: A status identifier (contains undefined codes)
         Parameter 4: Indicate synchronous/asynchronous decoding, or whether the decoder intends to drop frames
         Parameter 5: Buffer of the actual image
         Parameter 6: Timestamp of occurrence
         Parameter 7: Duration of appearance
         */
        setCallBack()
        var callbackRecord = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: callback, decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        /*
         Decoding parameters:
         * kCVPixelBufferPixelFormatTypeKey: the output data format of the camera
         kCVPixelBufferPixelFormatTypeKey, the measured available value is
         kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, which is 420v
         kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, which is 420f
         kCVPixelFormatType_32BGRA, iOS converts YUV to BGRA format internally
         YUV420 is generally used for standard-definition video, and YUV422 is used for high-definition video. The limitation here is surprising. However, under the same conditions, the calculation time and transmission pressure of YUV420 are smaller than those of YUV422.
         
         * kCVPixelBufferWidthKey/kCVPixelBufferHeightKey: the resolution of the video source width*height
         * kCVPixelBufferOpenGLCompatibilityKey: It allows the decoded image to be drawn directly in the context of OpenGL instead of copying data between the bus and the CPU. This is sometimes called a zero-copy channel, because the undecoded image is copied during the drawing process.
         
         */
        let imageBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey:width,
            kCVPixelBufferHeightKey:height,
            //            kCVPixelBufferOpenGLCompatibilityKey:true
        ] as [CFString : Any]
        
        //Create session
        
        /*!
         @function VTDecompressionSessionCreate
         @abstract creates a session for decompressing video frames.
         @discussion The decompressed frame will be sent out by calling OutputCallback
         @param allocator memory session. By using the default kCFAllocatorDefault allocator.
         @param videoFormatDescription describes the source video frame
         @param videoDecoderSpecification specifies the specific video decoder that must be used. NULL
         @param destinationImageBufferAttributes describes the requirements of the source pixel buffer NULL
         @param outputCallback Callback called using the decompressed frame
         @param decompressionSessionOut points to a variable to receive a new decompression session
         */
        let state = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: decodeDesc!, decoderSpecification: nil, imageBufferAttributes: imageBufferAttributes as CFDictionary, outputCallback: &callbackRecord, decompressionSessionOut: &decompressionSession)
        if state != noErr {
            print("Failed to create decodeSession")
        }
        VTSessionSetProperty(self.decompressionSession!, key: kVTDecompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        
        return true
        
    }
    //Successfully decoded back
    private func setCallBack()  {
        //(UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, OSStatus, VTDecodeInfoFlags, CVImageBuffer?, CMTime, CMTime) -> Void
        callback = { decompressionOutputRefCon,sourceFrameRefCon,status,inforFlags,imageBuffer,presentationTimeStamp,presentationDuration in
            let decoder : H265Decoder = unsafeBitCast(decompressionOutputRefCon, to: H265Decoder.self)
            guard imageBuffer != nil else {
                return
            }
            //            sourceFrameRefCon = imageBuffer
            if let block = decoder.decodeCallback  {
                decoder.callBackQueue.async {
                    block(imageBuffer)
                }
                
            }
        }
    }
    func decode(data:Data) {
        decodeQueue.async {
            let length:UInt32 =  UInt32(data.count)
            self.decodeByte(data: data, size: length)
        }
    }
    private func decodeByte(data:Data,size:UInt32) {
        //Data type: The first 4 bytes of frame are the start code of NALU data, which is 00 00 00 01,
        // Convert the start code of NALU to 4-byte big-endian NALU length information
        let naluSize = size - 4
        let length : [UInt8] = [
            UInt8(truncatingIfNeeded: naluSize >> 24),
            UInt8(truncatingIfNeeded: naluSize >> 16),
            UInt8(truncatingIfNeeded: naluSize >> 8),
            UInt8(truncatingIfNeeded: naluSize)
        ]
        var frameByte :[UInt8] = length
        [UInt8](data).suffix(from: 4).forEach { (bb) in
            frameByte.append(bb)
        }
        let bytes = frameByte //[UInt8](frameData)
        // The fifth byte is the data type, after converting to decimal, 7 is sps, 8 is pps, and 5 is IDR (I frame) information
        let type :Int  = Int(bytes[4] & 0x7E) >> 1
        switch type{
        case 0x13:
            if initDecoder() {
                decode(frame: bytes, size: size)
            }
        case 0x20:
            vpsData = data
        case 0x21:
            spsData = data
        case 0x22:
            ppsData = data
        default:
            if initDecoder() {
                decode(frame: bytes, size: size)
            }
        }
    }
    
    private func decode(frame:[UInt8],size:UInt32) {
        //
        var blockBUffer :CMBlockBuffer?
        var frame1 = frame
        //        var memoryBlock = frame1.withUnsafeMutableBytes({$0}).baseAddress
        //        var ddd = Data(bytes: frame, count: Int(size))
        //Create blockBuffer
        /*!
         Parameter 1: structureAllocator kCFAllocatorDefault
         Parameter 2: memoryBlock frame
         Parameter 3: frame size
         Parameter 4: blockAllocator: Pass NULL
         Parameter 5: customBlockSource Pass NULL
         Parameter 6: offsetToData data offset
         Parameter 7: dataLength data length
         Parameter 8: flags function and control flags
         Parameter 9: newBBufOut blockBuffer address, cannot be empty
         */
        let blockState = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                            memoryBlock: &frame1,
                                                            blockLength: Int(size),
                                                            blockAllocator: kCFAllocatorNull,
                                                            customBlockSource: nil,
                                                            offsetToData:0,
                                                            dataLength: Int(size),
                                                            flags: 0,
                                                            blockBufferOut: &blockBUffer)
        if blockState != noErr {
            print("Failed to create blockBuffer")
        }
        //
        var sampleSizeArray :[Int] = [Int(size)]
        var sampleBuffer :CMSampleBuffer?
        //Create sampleBuffer
        /*
         Parameter 1: allocator allocator, use the default memory allocation, kCFAllocatorDefault
         Parameter 2: blockBuffer. The data blockBuffer that needs to be encoded. Cannot be NULL
         Parameter 3: formatDescription, video output format
         Parameter 4: numSamples.CMSampleBuffer number.
         Parameter 5: numSampleTimingEntries must be 0,1,numSamples
         Parameter 6: sampleTimingArray. Array. Empty
         Parameter 7: numSampleSizeEntries defaults to 1
         Parameter 8: sampleSizeArray
         Parameter 9: sampleBuffer object
         */
        let readyState = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                                   dataBuffer: blockBUffer,
                                                   formatDescription: decodeDesc,
                                                   sampleCount: CMItemCount(1),
                                                   sampleTimingEntryCount: CMItemCount(),
                                                   sampleTimingArray: nil,
                                                   sampleSizeEntryCount: CMItemCount(1),
                                                   sampleSizeArray: &sampleSizeArray,
                                                   sampleBufferOut: &sampleBuffer)
        if readyState != noErr {
            print("Sample Buffer Create Ready faile")
        }
        //Decode data
        /*
         Parameter 1: Decoding session
         Parameter 2: Source data CMsampleBuffer containing one or more video frames
         Parameter 3: Decoding flag
         Parameter 4: decoded data outputPixelBuffer
         Parameter 5: Synchronous/asynchronous decoding identification
         */
        let sourceFrame:UnsafeMutableRawPointer? = nil
        var inforFalg = VTDecodeInfoFlags.asynchronous
        let decodeState = VTDecompressionSessionDecodeFrame(self.decompressionSession!, sampleBuffer: sampleBuffer!, flags:VTDecodeFrameFlags._EnableAsynchronousDecompression , frameRefcon: sourceFrame, infoFlagsOut: &inforFalg)
        if decodeState != noErr {
            print("Decoding failed")
        }
        
        
        
        let attachments:CFArray? = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, createIfNecessary: true)
        if let attachmentArray = attachments {
            let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachmentArray, 0), to: CFMutableDictionary.self)

            CFDictionarySetValue(dic,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        decodeWithSampeBufferCallback?(sampleBuffer!)
    }
    
    deinit {
        if decompressionSession != nil {
            VTDecompressionSessionInvalidate(decompressionSession!)
            decompressionSession = nil
        }
        
    }
}
