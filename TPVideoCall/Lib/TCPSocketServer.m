////
////  TCPSocketServer.m
////  TPVideoCall
////
////  Created by Truc Pham on 24/05/2022.
////
//
//#import <Foundation/Foundation.h>
//#import "TCPSocketServer.h"
//#import "HeaderDefine.h"
//
//#include <stdio.h>
//#include <stdlib.h>
//#include <errno.h>
//#include <string.h>
//#include <sys/types.h>
//#include <netinet/in.h>
//#include <sys/socket.h>
//#include <sys/wait.h>
//#include <sys/stat.h>
//#include <unistd.h>
//#include <arpa/inet.h>
//#include <fcntl.h>
//#include <err.h>
//#include <netdb.h>
//#include <sys/ioctl.h>
//#include <net/if.h>
//#include <pthread.h>
//#include <time.h>
//#include <signal.h>
//#include <sys/select.h>
//#include <sys/ioctl.h>
//#include <net/if.h>
//#include <string.h>
//#include <netinet/in.h>
//#include <net/if_dl.h>
//#include <ifaddrs.h>
//#include <errno.h>
//#include <netdb.h>
//
//pthread_mutex_t  mutex_cRecv=PTHREAD_MUTEX_INITIALIZER;
//pthread_mutex_t  mutex_cSend=PTHREAD_MUTEX_INITIALIZER;
//pthread_mutex_t  mutex_dRecv=PTHREAD_MUTEX_INITIALIZER;
//pthread_mutex_t  mutex_dSend=PTHREAD_MUTEX_INITIALIZER;
//@implementation TCPSocketServer
//
//+ (TCPSocketServer *)shared
//{
//  static TCPSocketServer *sharedSingleton;
//  @synchronized(self)
//  {
//    if (!sharedSingleton)
//      sharedSingleton = [[TCPSocketServer alloc] init];
//
//    return sharedSingleton;
//  }
//}
//
//-(void)decompileDataWithReturnData:(DecompileDataReceiveBlock)block
//{
//    while (true) {
//        
//        // 不知道是什么类型的数据
//        MsgHeader msgHeader;
//        memset(&msgHeader, 0, sizeof(msgHeader));
//        // 读包头
////        printf("---- sizeof(msgHeader) = %d\n", (int)sizeof(msgHeader));
//        if (![self recvDataSocketData:(char *)&msgHeader dataLength:sizeof(msgHeader)])
//        {
//            return;
//        }
//        char tempMsgHeader[5]={0};
//        memcpy(tempMsgHeader, &msgHeader.protocolHeader, sizeof(tempMsgHeader));
//        memset(tempMsgHeader+4, 0, 1);
//        
//        NSString* headerStr=[NSString stringWithCString:tempMsgHeader encoding:NSASCIIStringEncoding];
//        if ([headerStr compare:@"TRUC"] == NSOrderedSame) {
//            
//            // 视频数据
//            if(msgHeader.controlMask == CODECONTROLL_VIDEOTRANS_REPLY )
//            {
//                VideoDataContent dataContent;
//                memset(&dataContent, 0, sizeof(dataContent));
////                printf("----- sizeof(dataContent) = %d\n",(int)sizeof(dataContent));
//                if([self recvDataSocketData:(char*)&dataContent dataLength:sizeof(dataContent)])
//                {
//                    // ---- 来一份数据就向缓冲里追加一份 ----
//                    
//                    const size_t kRecvBufSize = 204800;
//                    char* buf = (char*)malloc(kRecvBufSize * sizeof(char));
//                    
//
//                    int dataLength = dataContent.videoLength;
//                    printf("------ struct video len = %d\n",dataLength);
//                    
//                    if([self recvDataSocketData:(char*)buf dataLength:dataLength])
//                    {
//                        
//                        // 接收到视频,
//                        //解码 ---> OpenGL ES渲染
//                        //
//                        block(buf, dataLength);
//                        
//                    }
//                }
//                
//            }
//            
//            // 音频数据
//            else if(msgHeader.controlMask==CONTROLLCODE_AUDIOTRANS_REPLY)
//            {
////                AudioDataContent dataContent;
////                memset(&dataContent, 0, sizeof(dataContent));
//////                printf("------ audio sizeof(dataContent) = %d \n",(int)sizeof(dataContent));
////                if([self recvDataSocketData:(char*)&dataContent dataLength:sizeof(dataContent)])
////                {
////                    //音频数据Buffer
////                    const size_t kRecvBufSize = 40000; // 1280
////                    char* dataBuf = (char*)malloc(kRecvBufSize * sizeof(char));
////
////                    int audioLength=dataContent.dataLength;
//////                    printf("---- audio audioLength = %d \n", audioLength);
////                    if([self recvDataSocketData:dataBuf dataLength:audioLength])
////                    {
////                        //接收到音频以后的处理
////                        if ([_delegate respondsToSelector:@selector(recvAudioData:andDataLength:)]) {
////                            [_delegate recvAudioData:(unsigned char *)dataBuf andDataLength:audioLength];
////                        }
////                    }
////                }
//            }
//        }
//    }
//}
//
//- (BOOL)recvDataSocketData: (char*)pBuf dataLength: (int)aLength
//{
//    signal(SIGPIPE, SIG_IGN);  // 防止程序收到SIGPIPE后自动退出
//    
//    pthread_mutex_lock(&mutex_dRecv);
//    
//    int recvLen=0;
//    long nRet=0;
////    printf("------ aLength = %d -------\n", aLength);
//    while(recvLen<aLength)
//    {
//        nRet=recv(m_dataSockfd,pBuf,aLength-recvLen,0);
//        
//        if(-1==nRet || 0==nRet)
//        {
//            pthread_mutex_unlock(&mutex_dRecv);
//            printf("DSocket recv error\n\n");
//            return false;
//        }
//        recvLen+=nRet;
//        pBuf+=nRet;
//        
//        printf("接收了%d个字节,\n\n",recvLen);
//
//    }
//    
//    pthread_mutex_unlock(&mutex_dRecv);
//    
//    return true;
//}
//
//
//-(void)combineData:(NSData*)data andReturnData:(CombineDataBlock)block
//{
//    Byte *myByte = (Byte *)[data bytes];
//    printf("=== send video dataLen = %d\n", (int)[data length]);
//
//    VideoDataContent dataContent;
//    memset((void *)&dataContent, 0, sizeof(dataContent));
//    
//    dataContent.msgHeader.controlMask = CODECONTROLL_VIDEOTRANS_REPLY;
//    dataContent.msgHeader.protocolHeader[0] = 'T';
//    dataContent.msgHeader.protocolHeader[1] = 'R';
//    dataContent.msgHeader.protocolHeader[2] = 'U';
//    dataContent.msgHeader.protocolHeader[3] = 'C';
//    
//    dataContent.videoLength = (unsigned int)[data length];
//    
//    int dataLen = (int)[data length];
//    int contentLen = sizeof(dataContent);
//    int totalLen = contentLen + dataLen;
//    
//    char *sendBuf = (char*)malloc(totalLen * sizeof(char));
//    memcpy(sendBuf, &dataContent, contentLen);
//    memcpy(sendBuf + contentLen, myByte, dataLen); // myByte是指针，所以不用再取地址了，注意
//    
//    block(sendBuf, totalLen);
//    
//}
//
//@end
//
