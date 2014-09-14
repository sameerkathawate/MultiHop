

#include <Timer.h>
#include "MultiHop.h"
#include <Serial.h>

module MultiHopC {
	uses interface Boot;
	uses interface Leds;
	uses interface Timer<TMilli> as Timer0; // Timer for Sending Invitation Packets 
	uses interface Timer<TMilli> as Timer1; // Timer for Sending sensor Data Packets
	uses interface Timer<TMilli> as Timer2; // One Shot Timer
	uses interface Timer<TMilli> as Timer3;  //Timer for sending text File packets
	uses interface Timer<TMilli> as ResolutionTimer;  //Timer for sending text File packets

	uses interface AMPacket;
	uses interface Packet  as RadioPacket;
	uses interface AMSend as AMRadioSend;
	uses interface Receive as RadioReceive;
	uses interface SplitControl as AMRadioControl;

	uses interface SplitControl as AMSerialControl;
	uses interface Receive as AMSerialReceive;
	uses interface AMSend  as AMSerialSend;
	uses interface Packet  as SerialPacket;
	uses interface CC2420Packet ;

	uses interface CC2420Config;
	uses interface PacketAcknowledgements;//Link Layer acknowledgements
}

implementation {
	uint16_t   datacounter = 0;
	uint16_t   invcounter = 0;
	uint8_t    parent_counter = 0;
	uint16_t   endid=0x0100; // Used by root node for calculating address of end node
	uint16_t   globalid; //unique global id of end node
	uint16_t   gatewayId;  //network ID of root node
	uint16_t   newid;   //  network id of end node
	uint16_t   endnodeid;
	uint16_t   reqnodeid; // indicates child node who had received join request from other nodes 
  
	//counters
	uint16_ti=0;
	uint16_tj=0;
	uint16_tk=0;
	uint16_tp=0;
  
	uint8_t currpacket = 0x01; // Sequence number of text file packets 
	uint8_t  file[1000];
	uint8_t childnum=0x00; // used for counting number of children
	uint8_t needid=0x00; // used by child node to tell its parent that it received a join request
	uint16_t   networkid; //network id of root
	ChildNwTable tab1[25]; // Table to store record of child nodes who extended their network
	NetworkTable record[2]; // Table to store global unique Id's ,network ID's of child nodes
	bool  radiobusy = FALSE; // Whether radio is busy or not
	bool  serialbusy = FALSE; // Checks Whether serial interface is busy

	message_t   radiopkt;
	message_t   serialpkt;
	bool  isRoot  = FALSE ; /* Becomes FALSE for end nodes */ 	

	bool  isRegistered = FALSE; /*Check whether node is registered or not*/
	bool  ackJoin=FALSE; /*When its true makes the root node to send acknowledgment packet */
	bool  datasink=FALSE; /* Used to distinguish datasink node from rest of nodes */
	bool  datasource=TRUE; /* Used to distinguish datasource node from rest of nodes */
	bool  inv = FALSE; /* used for starting the invitation timer of child node */
	bool  sendtext=FALSE; /* used for starting the timer for sending text file */
 
	event  void Boot.booted() {
		call AMSerialControl.start();
	}
	
	event  void AMSerialControl.startDone(error_t err) {
		if (err == SUCCESS)  {
		/* Start the Radio control after serial control is completed */
			call AMRadioControl.start();
		}
		else {
			call AMSerialControl.start();
		}
	}

	event void AMSerialControl.stopDone(error_t err) {
		call AMSerialControl.start();
	}

	event  void AMRadioControl.startDone(error_t err) {
		if (err == SUCCESS)  {
			call CC2420Config.sync();
			call Timer2.startOneShot(TIMER_PERIOD_WAIT); /* starts one shot timer which make node to wait for 5 sec */
		}
		else {
			call AMRadioControl.start();
		}
	}

	event void CC2420Config.syncDone(error_t err) {
		radiobusy=FALSE;
	}
	   
	event  void AMRadioControl.stopDone(error_t err) {
		call AMRadioControl.start();
	}
	   
	/* Timer 2 is one shot timer Which makes the node to wait for 5 seconds
	If within 5 seconds node receives a invitation Packet it becomes end node
	Otherwise declare it as a root node */
	event void Timer2.fired() { 

		isRoot=TRUE;
		isRegistered = TRUE;
		datasink=TRUE;
		networkid=0x0100;
		newid=networkid;
		call Leds.set(0x0020); 
		call Timer0.startPeriodic(TIMER_PERIOD_INVITATION);

	}
	 
	/* Timer 0 sends the invitation packet every second however when roots gets the join request
	it sets ackjoin= TRUE making timer 0 to send Sends Acknowledgement Packet for one cycle */
	event void Timer0.fired()
	{
		invcounter++;
		call Leds.led0Toggle();
		if (!radiobusy)
		{
			if(!ackJoin)
			{ /*sends Invitation Packet */ 
				ControlMsg* invpkt = (ControlMsg*) (call RadioPacket.getPayload(&radiopkt, sizeof(ControlMsg)));
				if(invpkt==NULL)
				{
				return;
				}
				invpkt->destID = 0xFFFF;  // All invitation messages are to be broadcasted
				invpkt->sourceID = TOS_NODE_ID; // Global unique id
				invpkt->packetType = InvPacket;
				if(call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(ControlMsg)) == SUCCESS)
				{
					radiobusy = TRUE;
					call Leds.set(0x0015);
					//invcounter++;
				}
			}
			else
			{  /*Sends Acknowledgement Packet*/
				AckMsg* ackpkt = (AckMsg*) (call RadioPacket.getPayload(&radiopkt, sizeof(AckMsg)));
				if(ackpkt==NULL)
				{
					return;
				}
				ackpkt->destID= globalid; //unique global id of end node
				ackpkt->sourceID = networkid;
				ackpkt->packetType= AckPacket;
				ackpkt->endglobalID= globalid; 
				ackpkt->endnetID = newid; // new network of end node
				if(call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(AckMsg)) == SUCCESS)
				{
					radiobusy = TRUE;
					call Leds.led0Toggle();
					call Leds.set(0x0010);
					ackJoin=FALSE; /* Setting again ackJoin=False so that timer 0 can send invitation packets */
				}

			}
		}
	} //End of event Timer0.fired

	event void Timer1.fired()
	{ /* Sends Data Packet */
		datacounter++;
		if (!radiobusy)
		{  
			DataMsg* datapkt = (DataMsg*) (call RadioPacket.getPayload(&radiopkt, NULL));
			datapkt->destID = 0x0100;  
			datapkt->sourceID = endnodeid; 
			datapkt->packetType = DataPacket;
			datapkt->nextHop = gatewayId;
			datapkt->sensorID = 0x0005;		
			datapkt->readingTime = 0x0002;
			datapkt->network = needid; 
			call PacketAcknowledgements.requestAck(&radiopkt); /* requesting for acknowledgement */
			if (call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(DataMsg)) == SUCCESS)
			{
				radiobusy = TRUE;
				call Leds.set(0x0010);
				//datacounter++;
			} 
		}
		if(datasource && sendtext==FALSE)
		{ // creating 1000 bytes file
			for(k=0;k<1000;k++)
				file[k]=0x08;
			
			sendtext=TRUE;
			call Timer3.startPeriodic(TIMER_PERIOD_FILEDATA);
		}
	}
	   
	/* Sending Text Data */
	event void Timer3.fired() {
		if (!radiobusy)
		{  
			FileMsg* filepkt = (FileMsg*) (call RadioPacket.getPayload(&radiopkt, NULL));
			filepkt->destID = 0x0100;  
			filepkt->sourceID = endnodeid; 
			filepkt->packetType = FilePacket;
			filepkt->nextHop = gatewayId;
			filepkt->sequencenum = currpacket;
			for(k=0;k<100;k++)
			{
				//loading fragment of 100 bytes of data present in the file
				filepkt->fileText[k] = file[p];
				p++;
			} 
			call PacketAcknowledgements.requestAck(&radiopkt);
			if (call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(FileMsg)) == SUCCESS)
			{
				radiobusy = TRUE;
				call Leds.set(0x0007);
				currpacket++; 
			}  
		}
	}

	event void ResolutionTimer.fired()
	{
		call Timer2.startOneShot(TIMER_PERIOD_WAIT);
	}

	/* Function used by the root node to send parent id to the child node who wants to 
	extend its network */ 
	void extendfn()
	{
		parent_counter++;
		endid=endid+0x0100; //network id of end node
		/* maintaing table of child networks */ 
		tab1[j].networkID=reqnodeid;
		tab1[j].parentID=endid;
		j++;
		if (!radiobusy)
		{
			ExtendNw* extnw = (ExtendNw*) (call RadioPacket.getPayload(&radiopkt, sizeof(ExtendNw)));
			if(extnw==NULL)
			{
				return;
			}
			extnw->destID = reqnodeid; 
			extnw->sourceID = 0x0100;
			extnw->packetType = ExtendNetwork;
			extnw->newnetworkID = endid;
			extnw->parentNum=parent_counter;
			if(call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(ExtendNw)) == SUCCESS)
			{
				radiobusy = TRUE;
				//call Leds.set(0x0005);
			}
		}
	}

	event void AMRadioSend.sendDone(message_t* msg, error_t error)
	{
		radiobusy = FALSE;
		if((call PacketAcknowledgements.wasAcked(msg) && datasource))
		{
			//call Leds.led0Toggle();
		}
	}

	event void AMSerialSend.sendDone(message_t* bufPtr, error_t error)
	{
	serialbusy = FALSE;
	}

	event message_t* AMSerialReceive.receive(message_t* msg, void* payload, uint8_t len) {
	}

	/* Reception Of control messages ie. Invitation,Join or Acknowledgement Packets 
	OR Data Packets Or Extend Network Packet*/

	event message_t* RadioReceive.receive(message_t* msg, void* payload, uint8_t len)
	{
		if (len == sizeof(ControlMsg))
		{
			message_t  *receivedmsg = msg;			
			ControlMsg* btrmsg =(ControlMsg*) payload;

			/* Grownetwork packet when received by end node from root makes 
			end node to start its own invitation counter */ 
			if(btrmsg->packetType==GrowNetwork && inv==FALSE)
			{
				// call Leds.set(0x0007);
				if(isRegistered)
				{
					call Timer0.startPeriodic(TIMER_PERIOD_INVITATION);
					inv=TRUE;
				}
			}


			/*Received invitation message set isRoot False which makes timer2.fired to send join request */
			if((call Timer2.isRunning()) && btrmsg->packetType==InvPacket)
			{
				//If you find 2 root, go to sleep for random amount of time
				//and start as end node, if you dint find any other node
				//as root then claim that you are root
				if(isRoot && btrmsg->sourceID == 0x0100 && networkid == 0x0100)
				{
					isRoot = FALSE;
					isRegistered = FALSE;
					call ResolutionTimer.startOneShot(rand());
				}
				//If you receive an invitation packet, stop the oneshot timer
				//and send join request.
				isRoot=FALSE;
				call Timer2.stop();
				datasink=FALSE;
				if (!radiobusy)
				{
					ControlMsg* joinpkt = (ControlMsg*) (call RadioPacket.getPayload(&radiopkt, sizeof(ControlMsg)));
					if(joinpkt==NULL)
					{ 
						return;
					}
					joinpkt->destID=0xFFFF;
					joinpkt->sourceID=TOS_NODE_ID;
					joinpkt->packetType=JoinPacket;
					if (call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(ControlMsg)) == SUCCESS)
					{
						radiobusy = TRUE;
						call Leds.set(0x0010); 
						//invcounter++;
					}
				}
			}
		 
			/* If join request received is received by datasink(root),add nodes to the network table*/ 
			if(btrmsg->packetType==JoinPacket)
			{
				if(childnum<0x02)
				{
					datasource=FALSE;
					globalid=btrmsg->sourceID; // global unique id of end node
					if(datasink)
					{
						ackJoin=TRUE; 
						newid=newid+1;//network id of end node
						childnum=childnum+1;
						// adding node's global id & net id to table
						record[i].globalID=globalid;
						record[i].netID=newid;
						i++;
					} 
					else if (needid==0x00)
					{ 
						//end node request for parentid from root node
						needid=0x01;
						// call Leds.set(0x0007);
					}
					else if (needid == 0x01)
					{
						ackJoin=TRUE; 
						newid=newid+1;
						childnum=childnum+1; 
						record[i].globalID=globalid; /*adding node's global id & net idto table*/
						record[i].netID=newid;
						i++;
					}
				}
			}

		}
		/* when acknowledge packet is received it verifies that whether this packet is for this node
		and then calls the timer 1 to send data packets */
		else if (len == sizeof(AckMsg) && !datasink)
		{
			message_t  *receivedmsg = msg;
			AckMsg* btrmsg =(AckMsg*) payload;
			if(TOS_NODE_ID==btrmsg->endglobalID)
			{ 
				//check whether the packet is for this node
				isRegistered=TRUE;
				gatewayId=btrmsg->sourceID; //network ID of root node
				endnodeid=btrmsg->endnetID;
				call Leds.set(0x0007);
				call Timer1.startPeriodic(TIMER_PERIOD_SENSORDATA); 
			}
		}

		/* When end node receives extend network packet from root(datasink) node
		it extracts its parentid,computes network id for the node who sends join
		packet & set ackjoin=True for sending acknowledgement */

		else if (len == sizeof(ExtendNw) && !datasink)
		{
			message_t  *receivedmsg = msg;
			ExtendNw* btrnw =(ExtendNw*) payload;
			networkid = btrnw->newnetworkID;
			newid= networkid;
			ackJoin=TRUE; 
			newid=newid+1;
			childnum=childnum+1;
			record[i].globalID=globalid; /*adding node's global id & net id  to table*/
			record[i].netID=newid;
			i++;
			call Leds.set(0x0005);
		}
		 
		/* If the size of the message indicates a Data Message & node is not datasource
		receive the message. */
		else if (len == sizeof(DataMsg))
		{
			if(!datasource)
			{
				message_t  *receivedmsg = msg;
				DataMsg* btrmsg =(DataMsg*) payload;
				// Check whether the data packet is for this root node
				if(btrmsg->destID == 0x0100)
				{ 
					/* check that whether the root node has requested for parent id in data packet */
					if(btrmsg->network== 0x01)
					{
						reqnodeid=btrmsg->sourceID;
						extendfn();
					}
					/*If the receiving node is not datasource & destination of message is datasink node 
					& message is send by immediate child broadcasts the message with next hop field changed
					to immediate parent of node */
					if(!datasink)
					{ 
						if(btrmsg->nextHop==networkid && !datasource && !radiobusy)
						{
							DataMsg* brdcst = (DataMsg*) (call RadioPacket.getPayload(&radiopkt, NULL));
							brdcst->destID=btrmsg->destID;
							brdcst->sourceID = btrmsg->sourceID;
							brdcst->packetType = btrmsg->packetType;
							brdcst->nextHop = gatewayId;
							brdcst->sensorID = btrmsg->sensorID;
							brdcst->readingTime = btrmsg->readingTime;
							brdcst->network= btrmsg->network;
							if (call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(DataMsg)) == SUCCESS)
							{
								radiobusy = TRUE;
								call Leds.set(0x0002);
								//datacounter++;
							}

						}
					}

					/* If receiving node is DataSource, Packet is send to the serial port for display */
					else
					{
						if(!serialbusy)
						{
							DataMsg* btrpkt = (DataMsg*) (call SerialPacket.getPayload(&serialpkt, NULL));
							btrpkt->destID=btrmsg->destID;
							btrpkt->sourceID = btrmsg->sourceID;
							btrpkt->packetType = btrmsg->packetType;
							btrpkt->nextHop = btrmsg->nextHop;
							btrpkt->sensorID = btrmsg->sensorID;
							btrpkt->readingTime = btrmsg->readingTime;
							btrpkt->network= btrmsg->network;
							if (call AMSerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(DataMsg)) == SUCCESS) 
							{
								serialbusy = TRUE;
							}
							if (!radiobusy)
							{
								ControlMsg* growpkt = (ControlMsg*) (call RadioPacket.getPayload(&radiopkt, sizeof(ControlMsg)));
								if(growpkt==NULL)
								{
									return;
								}
								growpkt->destID = 0xFFFF;
								growpkt->sourceID = 0x01FE; 
								growpkt->packetType = GrowNetwork;
								if(call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(ControlMsg)) == SUCCESS) 
								{
									radiobusy = TRUE;
								}
							}
						}
					}
				}
		 
			}
		}

		/* receiving Text File Data */
		else if (len == sizeof(FileMsg)) 
		{
			if(!datasource)
			{
				message_t  *receivedmsg = msg;
				FileMsg* filemsg =(FileMsg*) payload;
				if(filemsg->destID == 0x0100)
				{ /* Check whether the data packet is for root node */
					call Leds.set(0x0007);

					/*If the receiving node is not datasource & destination of message is datasink node 
					& message is send by immediate child broadcasts the message with next hop field changed
					to immediate parent of node */
					if(filemsg->nextHop==networkid)
					{  /*test with datasink condition*/
						if(!datasink) 
						{
							if (!radiobusy)
							{  
								FileMsg* flbrdcst = (FileMsg*) (call RadioPacket.getPayload(&radiopkt, NULL));
								flbrdcst->destID=filemsg->destID;
								flbrdcst->sourceID = filemsg->sourceID;
								flbrdcst->packetType = filemsg->packetType;
								flbrdcst->nextHop = gatewayId;
								flbrdcst->sequencenum = filemsg->sequencenum;
								for(k=0;k<100;k++) 
								{
									flbrdcst->fileText[k] =filemsg->fileText[k];
								}
								if (call AMRadioSend.send(AM_BROADCAST_ADDR, &radiopkt, sizeof(FileMsg)) == SUCCESS)
								{
									radiobusy = TRUE;
									//call Leds.set(0x0002);
									//datacounter++;
								}

							}
						}
						/* If receiving node is DataSource, Text File Packet is send  to the serial port for display */
						else
						{
							if(!serialbusy)
							{ 
								FileMsg* ftrpkt = (FileMsg*) (call SerialPacket.getPayload(&serialpkt, NULL));
								ftrpkt->destID=filemsg->destID;
								ftrpkt->sourceID = filemsg->sourceID;
								ftrpkt->packetType = filemsg->packetType;
								ftrpkt->nextHop = filemsg->nextHop;
								ftrpkt->sequencenum = filemsg->sequencenum ;
								for(k=0;k<100;k++) 
								{
								ftrpkt->fileText[k] =filemsg->fileText[k];
								}
								if (call AMSerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(FileMsg)) == SUCCESS) 
								{
									serialbusy = TRUE;
								}
							}
						}
					}
				}
			}
		}
	return msg;
	}//End of event receive
}



