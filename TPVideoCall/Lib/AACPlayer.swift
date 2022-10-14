////
////  AACPlayer.swift
////  TPVideoCall
////
////  Created by Truc Pham on 12/10/2022.
////
//
//import Foundation
//import VideoToolbox
//
//struct MyData : NSObject {
//    // the audio file stream parser
//     // the audio queue
//          // audio queue buffers
//    
//    var packetDescs : [AudioStreamPacketDescription] = []   // packet descriptions for enqueuing audio
//    
//    var fillBufferIndex : Int = 0   // the index of the audioQueueBuffer that is being filled
//    var  bytesFilled : Int = 0                // how many bytes have been filled
//    var packetsFilled : Int = 0         // how many packets have been filled
//    
//    var inuse : [Bool] = []            // flags to indicate that a buffer is still in use
//    var started : Bool = false                  // flag to indicate that the queue has been started
//    // flag to indicate an error occurred
//    
//    //pthread_mutex_t mutex;            // a mutex to protect the inuse flags
//    //pthread_cond_t cond;            // a condition varable for handling the inuse flags
//    //pthread_cond_t done;            // a condition varable for handling the inuse flags
//}
//class AACPlayer : NSObject {
//    let kNumAQBufs = 3
//    var kAQBufSize : UInt32 = 128 * 1024
//    let kAQMaxPacketDescs = 512
//    var canPlay = false
//    var failed : Bool = false
//    
//    var audioFileStream : AudioFileStreamID?
//    var audioQueue: AudioQueueRef!
//    var audioQueueBuffer : AudioQueueBufferRef!
//    
//    override init() {
//        canPlay = true
//        initBasic()
//    }
//    
//    func initBasic(){
//        let selfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
//        var err = AudioFileStreamOpen(selfPointer, {[weak self] clientData,audioFileStream, propertyID, ioFlag in
//            guard let self = self else { return }
//            self.KKAudioFileStreamPropertyListener(clientData: clientData, audioFileStream: audioFileStream, propertyID: propertyID, ioFlag: ioFlag)
//        }, {[weak self] clientData, numberBytes, numberPackets, ioData, packetDescription in
//            guard let self = self else { return }
//            self.KKAudioFileStreamPacketsCallback(clientData: clientData, numberBytes: numberBytes, numberPackets: numberPackets, ioData: ioData, packetDescription: packetDescription)
//        }, kAudioFileAAC_ADTSType, &self.audioFileStream)
//        
//        if err != noErr {
//            print("AudioFileStreamOpen error")
//        }
//    }
//    
//    func KKAudioFileStreamPropertyListener(clientData: UnsafeMutableRawPointer, audioFileStream: AudioFileStreamID, propertyID: AudioFileStreamPropertyID, ioFlag: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
//        // this is called by audio file stream when it finds property values
//        
//        let this = unsafeBitCast(clientData, to: AACPlayer.self)
//        
//        switch propertyID {
//        case kAudioFileStreamProperty_ReadyToProducePackets:
//            // the file stream parser is now ready to produce audio packets.
//            // get the stream format.
//            var asbd : AudioStreamBasicDescription!
//            var asbdSize: UInt32 = 0
//            var err = noErr;
//            err = AudioFileStreamGetProperty(audioFileStream,
//                                                 kAudioFileStreamProperty_DataFormat,
//                                                 &asbdSize,
//                                                 &asbd)
//            if err != noErr {
//                print("kAudioFileStreamProperty_DataFormat error")
//                this.failed = true
//            }
//            print("------ get the stream format. -------\n");
//            // create the audio queue
//            err = AudioQueueNewOutput(&asbd,{clientData, AQ, buffer in
//                this.KKAudioQueueOutputCallback(clientData: clientData, AQ: AQ, buffer: buffer)
//            },clientData, nil, nil, 0, &this.audioQueue);
//            
//            if err != noErr {
//                print("AudioQueueNewOutput error")
//                this.failed = true
//            }
//            
//            // allocate audio queue buffers
//            err = AudioQueueAllocateBuffer(this.audioQueue,
//                                           kAQBufSize,
//                                           &this.audioQueueBuffer);
//            if err != noErr {
//                print("AudioQueueAllocateBuffer error")
//                this.failed = true
//            }
//            print("------ allocate audio queue buffers ------\n");
//            
//            // get the cookie size
//            var cookieSize : UInt32 = 0
//            var writable : DarwinBoolean = false
//            
//            err = AudioFileStreamGetPropertyInfo(audioFileStream,
//                                                 kAudioFileStreamProperty_MagicCookieData,
//                                                 &cookieSize,
//                                                 &writable);
//            if err != noErr {
//                print("kAudioFileStreamProperty_MagicCookieData error")
//                this.failed = true
//            }
//            
//            print("cookieSize \(cookieSize)\n");
//            
//            // get the cookie data
//            var cookieData: AudioStreamBasicDescription = AudioStreamBasicDescription()
//            err = AudioFileStreamGetProperty(audioFileStream,
//                                             kAudioFileStreamProperty_MagicCookieData,
//                                             &cookieSize,
//                                             &cookieData);
//            if err != noErr {
//                print("kAudioQueueProperty_MagicCookie error")
//                this.failed = true
//            }
//            print("------ set the cookie on the queue ------\n");
//            
//            // listen for kAudioQueueProperty_IsRunning
//            err = AudioQueueAddPropertyListener(this.audioQueue,
//                                                kAudioQueueProperty_IsRunning,
//                                                {clientData,AQ, propertyID in
//                this.KKAudioQueueRunningListener(clientData: clientData, AQ: AQ, propertyID: propertyID)
//            }, clientData)
//            
//            if err != noErr {
//                print("AudioQueueAddPropertyListener error")
//                this.failed = true
//            }
//            print("------- listen for kAudioQueueProperty_IsRunning -----");
//            
//        default:
//            break
//        }
//    }
//    
//    func KKAudioFileStreamPacketsCallback(clientData: UnsafeMutableRawPointer, numberBytes: UInt32, numberPackets: UInt32, ioData: UnsafeRawPointer, packetDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?) {
//        let this = unsafeBitCast(clientData, to: AACPlayer.self)
//        for i in 0..<numberPackets {
//            var packetOffset = packetDescription?[Int(i)].mStartOffset
//            var packetSize = packetDescription?[Int(i)].mDataByteSize
//            var bufSpaceRemaining = kAQBufSize - this.bytes
//        }
//        
//    }
//    
//    func KKAudioQueueOutputCallback(clientData: UnsafeMutableRawPointer?, AQ: AudioQueueRef, buffer: AudioQueueBufferRef) {
//        
//    }
//    
//    func KKAudioQueueRunningListener(clientData: UnsafeMutableRawPointer?, AQ: AudioQueueRef, propertyID: AudioQueuePropertyID) {
//     
//    }
//}
