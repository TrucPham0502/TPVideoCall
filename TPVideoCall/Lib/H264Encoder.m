//
//  H264Encoder.m
//  TPVideoCall
//
//  Created by Truc Pham on 23/05/2022.
//

#import <Foundation/Foundation.h>
#import "H264Encoder.h"

#import <VideoToolbox/VideoToolbox.h>


@interface H264Encoder() {
    int frameID;
    dispatch_queue_t m_EncodeQueue;
    VTCompressionSessionRef encodingSession;
}@end


@implementation H264Encoder

- (instancetype)init {
    self = [super init];
    if (self) {
        m_EncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0); // encode in thread
        [self initVideoToolbox];
    };
    return self;
}



-(void)initVideoToolbox {
    dispatch_sync(m_EncodeQueue, ^{
        frameID = 0;
        
        //1. tao session
        int width = 640, height = 480;
        OSStatus status = VTCompressionSessionCreate(NULL,
                                                     width,
                                                     height,
                                                     kCMVideoCodecType_H264,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     didCompressH264,
                                                     (__bridge void *)(self),
                                                     &encodingSession);
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        if (status == noErr) {
            NSLog(@"H264: session created");
            return ;
        }
        
        // ----- 2. Set session attribute -----
        // Set real-time encoded output (to avoid delays)
        VTSessionSetProperty(encodingSession,
                             kVTCompressionPropertyKey_RealTime,
                             kCFBooleanTrue);
        VTSessionSetProperty(encodingSession,
                             kVTCompressionPropertyKey_ProfileLevel,
                             kVTProfileLevel_H264_Baseline_AutoLevel);
        
        // Set keyframe (GOPsize) interval
        int frameInterval = 10;
        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault,
                                                       kCFNumberIntType,
                                                       &frameInterval);
        VTSessionSetProperty(encodingSession,
                             kVTCompressionPropertyKey_MaxKeyFrameInterval,
                             frameIntervalRef);

        
        int fps = 60;
        CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(encodingSession,
                             kVTCompressionPropertyKey_ExpectedFrameRate,
                             fpsRef);
        
        
        int bitRate = width * height * 3 * 4 * 8;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault,
                                                kCFNumberSInt32Type,
                                                &bitRate);
        VTSessionSetProperty(encodingSession,
                             kVTCompressionPropertyKey_AverageBitRate,
                             bitRateRef);
        
      
        int bitRateLimit = width * height * 3 * 4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(encodingSession);
        
    });
}
// Write the encoded data to a TCP file
-(void)returnDataToTCPWithHeadData:(NSData*)headData andData:(NSData*)data
{
    printf("---- Video encoded data size = %d + %d \n",(int)[headData length] ,(int)[data length]);
    NSMutableData *tempData = [NSMutableData dataWithData:headData];
    [tempData appendData:data];
    
    
    // pass to socket
    if (self.returnDataBlock) {
        self.returnDataBlock(tempData);
    }
}
-(void)startH264EncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer andReturnData:(ReturnDataBlock)block
{
    self.returnDataBlock = block;
    
    dispatch_sync(m_EncodeQueue, ^{
        [self encode:sampleBuffer];
    });
}

-(void)stopH264Encode
{
    [self endVideoToolbox];
}

- (void) encode:(CMSampleBufferRef )sampleBuffer
{
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    // 帧时间，如果不设置会导致时间轴过长。
    CMTime presentationTimeStamp = CMTimeMake(frameID++, 1000); // CMTimeMake(分子，分母)；分子/分母 = 时间(秒)
    VTEncodeInfoFlags flags;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL, NULL, &flags);
    if (statusCode != noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
        
        VTCompressionSessionInvalidate(encodingSession);
        CFRelease(encodingSession);
        encodingSession = NULL;
        return;
    }
}

void didCompressH264(void *outputCallbackRefCon,
                     void *sourceFrameRefCon,
                     OSStatus status,
                     VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer)
{
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags); // 0 1
    if (status != noErr){
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264Encoder *encoder = (__bridge H264Encoder*)(outputCallbackRefCon);
    
    // ----- Keyframes get SPS and PPS ------
    
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    // Determine whether the current frame is a key frame
    // Get sps & pps data
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr)
            {
                // Found pps
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder)
                {
                    [encoder gotSpsPps:sps pps:pps];  // Get sps & pps data
                }
            }
        }
    }
    
    
    // --------- data input ----------
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // Bốn byte đầu tiên của dữ liệu nalu trả về không phải là mã bắt đầu của 0001, mà là độ dài khung của chế độ endian lớn.
        
        // Loop to get nalu data
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // From big endian to system end
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:keyframe];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}
// Get sps & pps data
/*
  Sequence parameter set SPS: acts on a series of consecutive encoded images;
  Picture parameter set PPS: acts on one or more independent pictures in the encoded video sequence;
  */
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"-------- SpsPps length after encoding: gotSpsPps %d %d", (int)[sps length] + 4, (int)[pps length]+4);
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];

    [self returnDataToTCPWithHeadData:ByteHeader andData:sps];
    [self returnDataToTCPWithHeadData:ByteHeader andData:pps];
}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"--------- Encoded data length： %d -----", (int)[data length]);
    NSLog(@"----------- data = %@ ------------", data);
    
    // Change the first four bytes of all NALU data of each frame into 0x00 00 00 01 and then write to the file
    const char bytes[] = "\x00\x00\x00\x01";  // null null null title starts
    size_t length = (sizeof bytes) - 1; // Các ký tự chuỗi có đuôi ngầm là '\ 0'. Xóa '\ 0' trong đoạn trước,
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length]; // Sao chép dữ liệu có trong mảng C để khởi tạo dữ liệu của NSData

    [self returnDataToTCPWithHeadData:ByteHeader andData:data];

}

- (void)endVideoToolbox
{
    VTCompressionSessionCompleteFrames(encodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(encodingSession);
    CFRelease(encodingSession);
    encodingSession = NULL;
}




@end
