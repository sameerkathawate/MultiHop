#include <Timer.h>
#include <Serial.h>
#include "MultiHop.h"

configuration MultiHopAppC {

}

implementation {
   components MainC;
   components LedsC;
   components MultiHopC as App;
   components new TimerMilliC() as Timer0; 
   components new TimerMilliC() as Timer1; 
   components new TimerMilliC() as Timer2;
   components new TimerMilliC() as Timer3;
   components new TimerMilliC() as ResolutionTimer;
   // For Radio Communication 
   components ActiveMessageC;
   components new AMSenderC(AM_RADIOMESSAGE);
   components new AMReceiverC(AM_RADIOMESSAGE);
   
   // For Serial Communication 
   components new SerialAMSenderC(AM_RADIOMESSAGE);
   components SerialActiveMessageC;
   components new SerialAMReceiverC(AM_RADIOMESSAGE);
   // For obtaining Acknowledgements
   components  CC2420ActiveMessageC;
   components CC2420ControlC;
   App.PacketAcknowledgements->CC2420ActiveMessageC;
   App.CC2420Config->CC2420ControlC;
   
   
   
   App.Boot ->MainC;
   App.Leds ->LedsC;
   App.Timer0 -> Timer0;
   App.Timer1 -> Timer1;
   App.Timer2 -> Timer2;
   App.Timer3 -> Timer3;
   App.ResolutionTimer -> ResolutionTimer;
   App.RadioPacket ->AMSenderC;
   App.AMPacket -> AMSenderC;
   App.AMRadioSend -> AMSenderC;
   App.AMRadioControl -> ActiveMessageC;
   App.RadioReceive -> AMReceiverC;
   App.CC2420Packet -> CC2420ActiveMessageC;
   App.AMSerialSend -> SerialAMSenderC;
   App.AMSerialControl -> SerialActiveMessageC;
   App.SerialPacket -> SerialAMSenderC;
   App.AMSerialReceive -> SerialAMReceiverC;


}
