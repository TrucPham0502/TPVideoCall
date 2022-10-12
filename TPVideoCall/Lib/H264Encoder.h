//
//  H264Decoder.h
//  TPVideoCall
//
//  Created by Truc Pham on 23/05/2022.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef void (^ReturnDataBlock)(NSData *data);

@interface H264Encoder : NSObject

@property (nonatomic, copy) ReturnDataBlock returnDataBlock;

-(void)startH264EncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer andReturnData:(ReturnDataBlock)block;
-(void)stopH264Encode;


@end
