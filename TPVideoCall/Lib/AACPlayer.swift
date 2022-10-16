//
//  AACPlayer.swift
//  TPVideoCall
//
//  Created by Truc Pham on 12/10/2022.
//

import Foundation
import VideoToolbox
import AudioToolbox

class AACPlayer : NSObject {
    private let playQueue = DispatchQueue(label: "trucpham.playQueue")
    private let _lock = NSRecursiveLock()
    let kNumAQBufs = 3
    var kAQBufSize : UInt32 = 128 * 1024
    let kAQMaxPacketDescs : Int = 512
    var started : Bool = false
    var canPlay = false
    var failed : Bool = false
    var bytesFilled : UInt32 = 0
    var packetsFilled : Int = 0
    var fillBufferIndex : Int = 0
//    var done : Bool = false
    
    var packetDescs : [AudioStreamPacketDescription] = []
    var audioFileStream : AudioFileStreamID!
    var audioQueue: AudioQueueRef!
    var audioQueueBuffer : [AudioQueueBufferRef] = []
    var inuse : [Bool] = []
    
    override init() {
        canPlay = true
        super.init()
        initBasic()
    }
    
    func initBasic(){
        audioQueueBuffer = .init(repeating: .allocate(capacity: 0), count: kNumAQBufs)
        packetDescs = .init(repeating: .init(), count: kAQMaxPacketDescs)
        inuse = .init(repeating: false, count: kNumAQBufs)
        
        let selfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        let err = AudioFileStreamOpen(selfPointer, { clientData,audioFileStream, propertyID, ioFlag in
            let this = unsafeBitCast(clientData, to: AACPlayer.self)
            this.myPropertyListenerProc(clientData: clientData, audioFileStream: audioFileStream, propertyID: propertyID, ioFlag: ioFlag)
        }, { clientData, numberBytes, numberPackets, ioData, packetDescription in
            let this = unsafeBitCast(clientData, to: AACPlayer.self)
            this.myPacketsProc(clientData: clientData, numberBytes: numberBytes, numberPackets: numberPackets, ioData: ioData, packetDescription: packetDescription)
        }, kAudioFileAAC_ADTSType, &self.audioFileStream)
        
        if err != noErr {
            print("AudioFileStreamOpen error")
        }
    }
    
    func myPropertyListenerProc(clientData: UnsafeMutableRawPointer, audioFileStream: AudioFileStreamID, propertyID: AudioFileStreamPropertyID, ioFlag: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
        // this is called by audio file stream when it finds property values
        
        switch propertyID {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            // the file stream parser is now ready to produce audio packets.
            // get the stream format.
            var asbd : AudioStreamBasicDescription = .init()
            var asbdSize: UInt32 = UInt32(MemoryLayout.size(ofValue: asbd))
            var err = noErr;
            err = AudioFileStreamGetProperty(audioFileStream,
                                                 kAudioFileStreamProperty_DataFormat,
                                                 &asbdSize,
                                                 &asbd)
            if err != noErr {
                print("kAudioFileStreamProperty_DataFormat error")
                self.failed = true
                break;
            }
            print("------ get the stream format. -------\n");
            // create the audio queue
            err = AudioQueueNewOutput(&asbd,{clientData, AQ, buffer in
                let this = unsafeBitCast(clientData, to: AACPlayer.self)
                this.myAudioQueueOutputCallback(clientData: clientData, AQ: AQ, buffer: buffer)
            },clientData, nil, nil, 0, &self.audioQueue);
            
            if err != noErr {
                print("AudioQueueNewOutput error")
                self.failed = true
                break;
            }
            
            // allocate audio queue buffers
            for i in 0..<kNumAQBufs {
                var _audioQueue : AudioQueueBufferRef?
                err = AudioQueueAllocateBuffer(self.audioQueue,
                                               kAQBufSize,
                                               &_audioQueue);
                if err != noErr {
                    print("AudioQueueAllocateBuffer error")
                    self.failed = true
                    break;
                }
                print("------ allocate audio queue buffers ------\n");
                self.audioQueueBuffer[i] = _audioQueue!
            }
            
            // get the cookie size
            var cookieSize : UInt32 = 0
            var writable : DarwinBoolean = false
            
            err = AudioFileStreamGetPropertyInfo(audioFileStream,
                                                 kAudioFileStreamProperty_MagicCookieData,
                                                 &cookieSize,
                                                 &writable);
            if err != noErr {
                print("kAudioFileStreamProperty_MagicCookieData error")
                self.failed = true
                break;
            }
            
            print("cookieSize \(cookieSize)\n");
            
            // get the cookie data
            var cookieData: AudioStreamBasicDescription = AudioStreamBasicDescription()
            err = AudioFileStreamGetProperty(audioFileStream,
                                             kAudioFileStreamProperty_MagicCookieData,
                                             &cookieSize,
                                             &cookieData);
            if err != noErr {
                print("kAudioQueueProperty_MagicCookie error")
                self.failed = true
                break
            }
            print("------ set the cookie on the queue ------\n");
            
            // listen for kAudioQueueProperty_IsRunning
            err = AudioQueueAddPropertyListener(self.audioQueue,
                                                kAudioQueueProperty_IsRunning,
                                                {clientData, AQ, propertyID in
                let this = unsafeBitCast(clientData, to: AACPlayer.self)
                this.myAudioQueueIsRunningCallback(clientData: clientData, AQ: AQ, propertyID: propertyID)
            }, clientData)
            
            if err != noErr {
                print("AudioQueueAddPropertyListener error")
                self.failed = true
                break
            }
            print("------- listen for kAudioQueueProperty_IsRunning -----");
            
        default:
            break
        }
    }
    
    func myPacketsProc(clientData: UnsafeMutableRawPointer, numberBytes: UInt32, numberPackets: UInt32, ioData: UnsafeRawPointer, packetDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?) {
        guard let packetDescription = packetDescription else { return }
        for i in 0..<numberPackets {
            let i = Int(i)
            let packetOffset = packetDescription[Int(i)].mStartOffset
            let packetSize = packetDescription[Int(i)].mDataByteSize
            let bufSpaceRemaining = self.kAQBufSize - self.bytesFilled
            if bufSpaceRemaining < packetSize {
                print("*********** 1 ************\n")
                self.myEnqueueBuffer()
                self.waitForFreeBuffer()
            }
            // 将数据复制到音频队列缓冲区
            let fillBuf : AudioQueueBufferRef = self.audioQueueBuffer[self.fillBufferIndex]
            memcpy(fillBuf.pointee.mAudioData + UnsafeMutableRawPointer.Stride(self.bytesFilled), ioData + UnsafeRawPointer.Stride(packetOffset), Int(packetSize))
            // fill out packet description
            self.packetDescs[self.packetsFilled] = packetDescription[i]
            self.packetDescs[self.packetsFilled].mStartOffset = Int64(self.bytesFilled);
            // keep track of bytes filled and packets filled
            self.bytesFilled += packetSize;
            self.packetsFilled += 1;
            
            // if that was the last free packet description, then enqueue the buffer.
//                let packetsDescsRemaining = UInt32(kAQMaxPacketDescs) - self.packetsFilled;
            print("*********** 2 ************");
            self.myEnqueueBuffer();
            self.waitForFreeBuffer()
        }
    }
    
    func myEnqueueBuffer()
    {
        var err : OSStatus = noErr;
        self.inuse[self.fillBufferIndex] = true // set in use flag
        // enqueue buffer
        let fillBuf : AudioQueueBufferRef = self.audioQueueBuffer[self.fillBufferIndex]
        fillBuf.pointee.mAudioDataByteSize = self.bytesFilled
        err = AudioQueueEnqueueBuffer(self.audioQueue, fillBuf, UInt32(self.packetsFilled), self.packetDescs)
        if err != noErr {
            print("AudioQueueEnqueueBuffer error")
            self.failed = true
            return
        }
        startQueueIfNeeded()
        return
    }
    
    func startQueueIfNeeded()
    {
        var err : OSStatus = noErr;
        if (!self.started && canPlay) {        // start the queue if it has not been started already
            err = AudioQueueStart(self.audioQueue, nil);
            if (err != noErr) {
                print("AudioQueueStart Error")
                self.failed = true
                return
            }
            self.started = true
            print("started\n")
        }
        return
    }
    
    func waitForFreeBuffer()
    {
        // go to next buffer
        self.fillBufferIndex += 1
        if (self.fillBufferIndex >= kNumAQBufs) { self.fillBufferIndex = 0 }
        self.bytesFilled = 0;        // reset bytes filled
        self.packetsFilled = 0;        // reset packets filled
        
        // wait until next buffer is not in use
        print("waitForFreeBuffer->lock\n");
        while (self.inuse[self.fillBufferIndex]) {
            print("... WAITING ... \(fillBufferIndex)\n");
            _lock.lock()
        }
        print("... waitForFreeBuffer end ...\n");
    }
    
    func myAudioQueueOutputCallback(clientData: UnsafeMutableRawPointer?, AQ: AudioQueueRef, buffer: AudioQueueBufferRef) {
        // this is called by the audio queue when it has finished decoding our data.
        // The buffer is now free to be reused.
        
        if let bufIndex = self.audioQueueBuffer.firstIndex(where: { $0 == buffer }) {
            // signal waiting thread that the buffer is free.
            self.inuse[bufIndex] = false
            print("myAudioQueueOutputCallback->unlock\n")
            _lock.unlock()
        }
    }
    
    func myAudioQueueIsRunningCallback(clientData: UnsafeMutableRawPointer?, AQ: AudioQueueRef, propertyID: AudioQueuePropertyID) {
        var running : UInt32 = 0
        var size : UInt32 = 0
        let err : OSStatus = AudioQueueGetProperty(AQ,
                                             kAudioQueueProperty_IsRunning,
                                             &running,
                                             &size);
        if (err != noErr) {
            print("get kAudioQueueProperty_IsRunning");
            return;
        }
        if (running == 0) {
            self.stop()
        }
    }
    
    func stop()
    {
        playQueue.async {[weak self] in
            guard let self = self else { return }
            // enqueue last buffer
            self.myEnqueueBuffer()
            
            
            print("flushing\n");
            // AudioQueueFlush ---> 重新设置解码器的解码状态
            var err : OSStatus = AudioQueueFlush(self.audioQueue);
        //    if (err) { PRINTERROR("AudioQueueFlush"); free(buf); return 1; }
            
            print("stopping\n");
            err = AudioQueueStop(self.audioQueue, false);
            
            
            
        //    if (err) { PRINTERROR("AudioQueueStop"); free(buf); return 1; }
            
//            print("waiting until finished playing..\n");
//            print("start->lock\n");
//            while(!self.done) {
//                print("---starting audio----")
//            }
//            print("start->unlock\n");
//            print("done\n");
            
            // cleanup
        //    free(buf);
            err = AudioFileStreamClose(self.audioFileStream);
            err = AudioQueueDispose(self.audioQueue, false);
        }
        
    }

    //
    func audioPause()
    {
        // AudioQueuePause
        var err : OSStatus = noErr;
        if (self.started) {        // pause the queue if it has been started already
    //        err = AudioQueuePause(myData->audioQueue);
            err = AudioQueueStop(audioQueue, true);
            if (err != noErr) {
                print("AudioQueueStart");
                self.failed = true;
                
            }else{
                canPlay = false;
                self.started = false;
                print("paused\n");
            }
        }
    }
    
    
    func audioStart()
    {
        canPlay = true;
    //    StartQueueIfNeeded(myData);
    }
    
    func play(_ data : Data) {
        playQueue.async {
            let bytePtr = [UInt8](data)
            self.playAudioWithData(bytePtr, length: UInt32(data.count))
        }
    }
    func playAudioWithData(_ pBuf : [UInt8], length: UInt32)
    {
        // 解析数据. 将会调用 MyPropertyListenerProc 和 MyPacketsProc
        let err : OSStatus = AudioFileStreamParseBytes(self.audioFileStream, length,
                                        pBuf,
                                                       AudioFileStreamParseFlags(rawValue: 0));
        if (err != noErr)
        {
            print("AudioFileStreamParseBytes");
        }
    }

}
