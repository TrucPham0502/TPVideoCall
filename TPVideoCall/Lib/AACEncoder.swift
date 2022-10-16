//
//  AACEncoder.swift
//  TPVideoCall
//
//  Created by Truc Pham on 25/05/2022.
//

import Foundation
import AudioToolbox
import CoreMedia
class AACEncoder {
    var audioConverter : AudioConverterRef!
    var aacBuffer : UnsafeMutableRawPointer?
    var aacBufferSize : UInt32 = 1024
    var pcmBuffer : UnsafeMutablePointer<Int8>?
    var pcmBufferSize : Int = 0
    var encodeQueue = DispatchQueue(label: "audio.encode")
    var callBackQueue = DispatchQueue(label: "audio.callBack")
    var encodeCallback : ((Data)-> Void) = {_ in }
    init(){
        aacBuffer = .allocate(byteCount: Int(aacBufferSize) * MemoryLayout<UInt32>.size, alignment: MemoryLayout<UnsafeMutableRawPointer>.alignment)
    }
    
    func setupEncoderFromSampleBuffer(sampleBuffer : CMSampleBuffer){
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let inAudioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)
        var pointee = inAudioStreamBasicDescription!.pointee
        var outAudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: pointee.mSampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: kAudioFormatFlagIsSignedInteger,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 0,
            mReserved: 0)
        
        
        
        var audioDescription = self.getAudioClassDescription(with: kAudioFormatMPEG4AAC, fromManufacturer: kAppleSoftwareAudioCodecManufacturer)
        
        let state = AudioConverterNewSpecific(
            &pointee,
            &outAudioStreamBasicDescription,
            1,
            &audioDescription,
            &self.audioConverter)
        
        if state != noErr {
            print("setup converter: \(state)")
        }
        
    }
    
    
    func getAudioClassDescription(with type : UInt32, fromManufacturer: UInt32) -> AudioClassDescription {
        
        var audioDescription = AudioClassDescription()
        var encoderSpecifier : UInt32 = type
        var size : UInt32 = 0
        
        
        let state = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, UInt32(MemoryLayout.size(ofValue: encoderSpecifier)), &encoderSpecifier, &size)
        
        if state != noErr {
            print("error getting audio format propery info: \(state)")
        }
        
        let count =  Int(size) / MemoryLayout.size(ofValue: audioDescription)
        
        var descriptions : [AudioClassDescription] = Array<AudioClassDescription>.init(repeating: AudioClassDescription(), count: count)
        
        let state1 = AudioFormatGetProperty(
            kAudioFormatProperty_Encoders,
            UInt32(MemoryLayout.size(ofValue: encoderSpecifier)),
            &encoderSpecifier,
            &size, 
            &descriptions)
        
        if state1 != noErr {
            print("error getting audio format propery \(state1)")
        }
        
        if let _descriptionIdx = descriptions.firstIndex(where: { kAudioFormatMPEG4AAC == $0.mSubType &&
            (fromManufacturer == $0.mManufacturer) }) {
            memcpy(&audioDescription , &(descriptions[_descriptionIdx]), MemoryLayout.size(ofValue: audioDescription))
        }
        return audioDescription
    }
    
    func encodeSampleBuffer(sampleBuffer : CMSampleBuffer) {
        encodeQueue.async {[weak self] in
            guard let _self = self else { return }
            if _self.audioConverter == nil {
                _self.setupEncoderFromSampleBuffer(sampleBuffer: sampleBuffer)
            }
            
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
            let state = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &_self.pcmBufferSize, dataPointerOut: &_self.pcmBuffer)
            if state != noErr {
                print("audio faile")
            }
            
            var outAudioBufferList : AudioBufferList = .init(mNumberBuffers: 1,
                                                             mBuffers: .init(mNumberChannels: 1, mDataByteSize: _self.aacBufferSize, mData: _self.aacBuffer))
            
//            let outPacketDescription : AudioStreamPacketDescription?
            var ioOutputDataPacketSize : UInt32 = 1
            let sb =  unsafeBitCast(_self, to: UnsafeMutableRawPointer.self)
            let status = AudioConverterFillComplexBuffer(_self.audioConverter, { inAudioConverter, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData  in
                
                
                let encoder = unsafeBitCast(inUserData, to:  AACEncoder.self)
                
                
                let requestedPackets = ioNumberDataPackets;
                //                NSLog(@"Number of packets requested: %d", (unsigned int)requestedPackets);
                let copiedSamples = encoder.pcmBufferSize
                let buffer = encoder.pcmBuffer
                ioData.pointee.mBuffers.mData = unsafeBitCast(buffer, to: UnsafeMutableRawPointer.self)
                ioData.pointee.mBuffers.mDataByteSize = UInt32(copiedSamples)
                encoder.pcmBuffer = nil
                encoder.pcmBufferSize = 0
                if (copiedSamples < requestedPackets.pointee) {
                    //PCM Buffer Not Full
                    ioNumberDataPackets.pointee = 0
                    return -1;
                }
                
                ioNumberDataPackets.pointee = UInt32(copiedSamples) / 2
                return noErr;
                
            }, sb , &ioOutputDataPacketSize, &outAudioBufferList, nil)
            if (status == noErr) {
                let rawAAC = Data(bytes: outAudioBufferList.mBuffers.mData!, count: Int(outAudioBufferList.mBuffers.mDataByteSize))
                let adtsHeader : Data = _self.adtsDataForPacketLength(rawAAC.count)
                let fullData = NSMutableData(data: adtsHeader)
                fullData.append(rawAAC)
                _self.encodeCallback(fullData as Data)
                
            } else {
                print("Error")
            }
        }
    }
    
    func adtsDataForPacketLength(_ packetLength : Int) -> Data {
        let adtsLength = 7
        var packet = [UInt8](repeating: 0x00, count: adtsLength)
        // Variables Recycled by addADTStoPacket
        let profile = 2  //AAC LC
        //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
        let freqIdx = 4  //44.1KHz
        let chanCfg = 1  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
        let fullLength = adtsLength + packetLength
        // fill in ADTS data
        
        packet[0] = 0xFF; // 11111111     = syncword
        packet[1] = 0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
        packet[2] = UInt8((((profile - 1) << 6) + (freqIdx << 2) + (chanCfg >> 2)))
        packet[3] = UInt8((((chanCfg & 3) << 6) + (fullLength >> 11)))
        packet[4] = UInt8(((fullLength & 0x7FF) >> 3))
        packet[5] = UInt8((((fullLength & 7) << 5) + 0x1F))
        packet[6] = 0xFC;
        let data = Data(bytes: &packet, count: adtsLength)
        return data
    }
    
    deinit {
        if let audioConverter = self.audioConverter { AudioConverterDispose(audioConverter) }
        free(self.aacBuffer)
    }
}
