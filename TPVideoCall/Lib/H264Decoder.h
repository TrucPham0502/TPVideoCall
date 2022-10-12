//
//  H264Decoder.h
//  TPVideoCall
//
//  Created by Truc Pham on 23/05/2022.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

typedef void (^ReturnDecodedVideoDataBlock) (CVPixelBufferRef pixelBuffer);
@interface H264Decoder : NSObject

@property (nonatomic, copy) ReturnDecodedVideoDataBlock returnDataBlock;

-(void)startH264DecodeWithVideoData:(NSData *)videoData andLength:(int)length andReturnDecodedData:(ReturnDecodedVideoDataBlock)block;
-(void)stopH264Decode;

@end
