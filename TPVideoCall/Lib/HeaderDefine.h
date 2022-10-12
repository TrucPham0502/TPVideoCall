
#ifndef HeaderDefine_h
#define HeaderDefine_h

#define     INT8           unsigned char
#define     INT16          unsigned short
#define     INT32          unsigned int


#define SCREENWIDTH [UIScreen mainScreen].bounds.size.width
#define SCREENHEIGHT [UIScreen mainScreen].bounds.size.height


#endif /* HeaderDefine_h */




static INT16        CODECONTROLL_DATATRANS_REQUEST          =0;   // 数据请求
static INT16        CODECONTROLL_VIDEOTRANS_REPLY           =1;   // 视频
static INT16        CONTROLLCODE_AUDIOTRANS_REPLY           =2;

typedef struct msgHeader
{
    unsigned char       protocolHeader[4];  // 协议头  HM_C 命令，HM_D 传数据
    short               controlMask;        // 操作码 :用来区分同一协议中的不同命令
    int                 contentLength;      // 正文长度-> 包后面跟的数据的长度
    
}MsgHeader;


typedef struct videoAndAudioDataRequest
{
    HJ_MsgHeader        msgHeader;
    
}VideoAndAudioDataRequest;

typedef struct videoDataContent
{
    HJ_MsgHeader        msgHeader;
    unsigned int        timeStamp;          // 时间戳
    unsigned int        frameTime;          // 帧采集时间
    unsigned char       reserved;           // 保留
    unsigned int        videoLength;        // video帧 size
    
}VideoDataContent;

typedef struct audioDataContent
{
    HJ_MsgHeader        msgHeader;
    unsigned int        timeStamp;          // 时间戳
    unsigned int        collectTime;        // 采集时间
    char                audioFormat;        // 音频格式
    unsigned int        dataLength;         // 数据长度
    
}AudioDataContent;
