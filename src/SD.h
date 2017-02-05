
#define SD_START_DATA_BLOCK_TOKEN          0xfe

#define SD_R1_RESPONSE       0x00

#define SD_SUCCESS           0x00
#define SD_BLOCK_SET_ERROR   0x01
#define SD_RESPONSE_ERROR    0x02
#define SD_DATA_TOKEN_ERROR  0x03
#define SD_INIT_ERROR        0x04
#define SD_CRC_ERROR         0x10
#define SD_WRITE_ERROR       0x11
#define SD_OTHER_ERROR       0x12
#define SD_TIMEOUT_ERROR     0xFF

#define SD_GO_IDLE_STATE          0x40
#define SD_SEND_OP_COND           0x41
#define SD_READ_CSD               0x49
#define SD_SEND_CID               0x4a
#define SD_STOP_TRANSMISSION      0x4c
#define SD_SEND_STATUS            0x4d
#define SD_SET_BLOCKLEN           0x50
#define SD_READ_SINGLE_BLOCK      0x51
#define SD_READ_MULTIPLE_BLOCK    0x52
#define SD_CMD_WRITEBLOCK         0x54
#define SD_WRITE_BLOCK            0x58
#define SD_WRITE_MULTIPLE_BLOCK   0x59
#define SD_WRITE_CSD              0x5b
#define SD_SET_WRITE_PROT         0x5c
#define SD_CLR_WRITE_PROT         0x5d
#define SD_SEND_WRITE_PROT        0x5e
#define SD_TAG_SECTOR_START       0x60
#define SD_TAG_SECTOR_END         0x61
#define SD_UNTAG_SECTOR           0x62
#define SD_TAG_EREASE_GROUP_START 0x63
#define SD_TAG_EREASE_GROUP_END   0x64
#define SD_UNTAG_EREASE_GROUP     0x65
#define SD_EREASE                 0x66
#define SD_READ_OCR               0x67
#define SD_CRC_ON_OFF             0x68

