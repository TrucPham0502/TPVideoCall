//
//  H264Decoder.m
//  TPVideoCall
//
//  Created by Truc Pham on 23/05/2022.
//

#import <Foundation/Foundation.h>
#import "H264Decoder.h"

@interface H264Decoder()
{
    VTDecompressionSessionRef   mDecodeSession;
    CMFormatDescriptionRef      mFormatDescription; //The format of video, including width and height, color space, encoding format, etc.; for H.264 video, the data of PPS and SPS are also here；
    
    uint8_t*        packetBuffer; // buffer for one frame // unsigned char *
    long            packetSize;    // size of a frame (length, bytes
    
    uint8_t     *mSPS;
    long        mSPSSize;
    uint8_t     *mPPS;
    long        mPPSSize;
    
}
@end

@implementation H264Decoder

- (instancetype)init{
    
    self = [super init];
    if (self) {
        
    }
    return self;
}

-(void)startH264DecodeWithVideoData:(NSData *)videoData andLength:(int)length andReturnDecodedData:(ReturnDecodedVideoDataBlock)block
{
    Byte *myByte = (Byte *)[videoData bytes];
    int dataLen = (int)[videoData length];
    
    char *sendBuf = (char*)malloc(dataLen * sizeof(char));
    memcpy(sendBuf, myByte, dataLen);
//    memcpy(sendBuf, myByte, dataLen); // myByte是指针，所以不用再取地址了，注意
    
    
    self.returnDataBlock = block;
    
    packetBuffer = (unsigned char *)sendBuf;
    packetSize = length;
    
    [self updateFrame];
}


-(void)stopH264Decode
{
    [self endVideoToolbox];
}

-(void)updateFrame {
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                            0), ^{
        // thay thế độ dài byte tiêu đề
        uint32_t nalSize = (uint32_t)(packetSize - 4);
        uint32_t *pNalSize = (uint32_t *)packetBuffer;
        *pNalSize = CFSwapInt32HostToBig(nalSize);
        
        
        
        // Byte tiếp theo sau khi chia cho 00 00 00 01 là kiểu --NALU--
        CVPixelBufferRef pixelBuffer = NULL;
        int nalType = packetBuffer[4] & 0x1F;  // Loại NALU & 0001 1111
        switch (nalType) {
            case 0x05:
//                NSLog(@"*********** IDR frame");
                [self initVideoToolbox]; //Initialize VideoToolbox when reading IDR frames and start synchronous decoding
                pixelBuffer = [self decode]; // The decoded CVPixelBufferRef will be passed to the OpenGL ES class for parsing and rendering
                break;
            case 0x07:
//                NSLog(@"*********** SPS");
                mSPSSize = packetSize - 4;
                mSPS = malloc(mSPSSize);
                memcpy(mSPS, packetBuffer + 4, mSPSSize);
                break;
            case 0x08:
//                NSLog(@"*********** PPS");
                mPPSSize = packetSize - 4;
                mPPS = malloc(mPPSSize);
                memcpy(mPPS, packetBuffer + 4, mPPSSize);
                break;
            default:
//                NSLog(@"*********** B/P frame"); // P帧?
                pixelBuffer = [self decode];
                
                break;
        }
        
        if(pixelBuffer) {
            self.returnDataBlock(pixelBuffer);
            CVPixelBufferRelease(pixelBuffer);
            
        }
        
        
    });
}

- (void)initVideoToolbox {
    if (!mDecodeSession) {
        // Wrap SPS and PPS into CMVideoFormatDescription
        const uint8_t* parameterSetPointers[2] = {mSPS, mPPS};
        const size_t parameterSetSizes[2] = {mSPSSize, mPPSSize};
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                              2, //param count
                                                                              parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              4, //nal start code size
                                                                              &mFormatDescription);
        if(status == noErr) {
            CFDictionaryRef attrs = NULL;
            const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
            //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
            //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
            uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
            const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
            attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
            
            VTDecompressionOutputCallbackRecord callBackRecord;
            callBackRecord.decompressionOutputCallback = didDecompress;
            callBackRecord.decompressionOutputRefCon = NULL;
            
            status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                  mFormatDescription,
                                                  NULL, attrs,
                                                  &callBackRecord,
                                                  &mDecodeSession);
            CFRelease(attrs);
        } else {
            NSLog(@"IOS8VT: reset decoder session failed status = %d", (int)status);
        }
    }
}

void didDecompress(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}


-(CVPixelBufferRef)decode {
    
    CVPixelBufferRef outputPixelBuffer = NULL;
    if (mDecodeSession) {
        // Wrap NALUnit with CMBlockBuffer (uncompressed image data)
        CMBlockBufferRef blockBuffer = NULL;
        OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                              (void*)packetBuffer, packetSize,
                                                              kCFAllocatorNull,
                                                              NULL, 0, packetSize,
                                                              0, &blockBuffer);
        if(status == kCMBlockBufferNoErr) {
            // ---- Create CMSampleBuffer ---- Pack the original stream into CMSampleBuffer (store one or more compressed or uncompressed media files)
            CMSampleBufferRef sampleBuffer = NULL;
            const size_t sampleSizeArray[] = {packetSize};
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               blockBuffer,        // Wrap NALUnit with CMBlockBuffer
                                               mFormatDescription, // Wrap SPS and PPS into CMVideoFormatDescription
                                               1, 0, NULL, 1, sampleSizeArray,
                                               &sampleBuffer);
            
            // ------------- decode and display -------------
            if (status == kCMBlockBufferNoErr && sampleBuffer) {
                
                VTDecodeFrameFlags flags = 0;
                VTDecodeInfoFlags flagOut = 0;
                // The default is a synchronous operation.
                // Call didDecompress and call back after returning
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(mDecodeSession,
                                                                          sampleBuffer,
                                                                          flags,
                                                                          &outputPixelBuffer,
                                                                          &flagOut);
                
                if(decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"IOS8VT: Invalid session, reset decoder session");
                } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                    NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
                    
                } else if(decodeStatus != noErr) {
                    NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
                    perror("decode failed, error:");
                }
                
                CFRelease(sampleBuffer);
            }
            CFRelease(blockBuffer);
        }
    }
    
    return outputPixelBuffer;
}

- (void)endVideoToolbox
{
    if(mDecodeSession) {
        VTDecompressionSessionInvalidate(mDecodeSession);
        CFRelease(mDecodeSession);
        mDecodeSession = NULL;
    }
    
    if(mFormatDescription) {
        CFRelease(mFormatDescription);
        mFormatDescription = NULL;
    }
    
    free(mSPS);
    free(mPPS);
    mSPSSize = mPPSSize = 0;
}

@end
