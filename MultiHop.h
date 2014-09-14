#ifndef MULTIHOP_H
#define MULTIHOP_H

enum {
     
     AM_RADIOMESSAGE = 6,				
     TIMER_PERIOD_INVITATION = 1200,		// Invitation message interval
     TIMER_PERIOD_SENSORDATA = 200,		// Sensor data reporting interval
	 TIMER_PERIOD_FILEDATA = 3000,
     TIMER_PERIOD_INVITATION1 = 2000,
     TIMER_PERIOD_WAIT=5000, // interval for which node waits before becoming root node
     WAIT_ROOT = 1500,
	 InvPacket=0x01,
     JoinPacket=0x02,
     AckPacket=0x03,
     DataPacket=0x04,
	 ExtendNetwork=0x05,
	 GrowNetwork=0x06,
	FilePacket = 0x07
};

//Structure for Invitation & join Packets
typedef nx_struct ControlMsg {
    nx_uint16_t  destID;
    nx_uint16_t  sourceID;
    nx_uint8_t  packetType;  
} ControlMsg;

//Structure for Data Packets
typedef nx_struct DataMsg {
    nx_uint16_t  destID;
    nx_uint16_t  sourceID;
	nx_uint16_t	nextHop;
    nx_uint8_t  packetType;  
    nx_uint16_t	sensorID;
    nx_uint16_t	readingTime;
    nx_uint8_t  network;
} DataMsg;

/* Structure for Text File Data Packet */
typedef nx_struct FileMsg {
    nx_uint16_t  destID;
    nx_uint16_t  sourceID;
	nx_uint16_t	nextHop;
    nx_uint8_t  packetType;  
	nx_uint8_t  sequencenum;
    nx_uint8_t  fileText[100];   
} FileMsg;


//Structure for Acknowledgement Packet
typedef nx_struct AckMsg {
    nx_uint16_t  destID;
    nx_uint16_t  sourceID;
    nx_uint8_t   packetType;   
    nx_uint16_t  endglobalID;
    nx_uint16_t  endnetID;
} AckMsg;

// Structure for Extending Network
typedef nx_struct ExtendNw {
    nx_uint16_t  destID;
    nx_uint16_t  sourceID;
    nx_uint8_t  packetType;
    nx_uint16_t  newnetworkID; 
    nx_uint8_t  parentNum;  
} ExtendNw;

// Structure to keep record of child node extended their network  
typedef nx_struct ChildNwTable {
    nx_uint16_t  networkID;
    nx_uint16_t  parentID;
} ChildNwTable;

/*Table to store global unique Id's ,network ID's of child nodes */
typedef nx_struct NetworkTable {
    nx_uint16_t  globalID;
    nx_uint16_t  netID;
} NetworkTable;



#endif


