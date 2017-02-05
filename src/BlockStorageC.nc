configuration BlockStorageC {
	
	provides {
		
		interface BlockRead;
		interface BlockWrite;
	}

}
implementation {
  components BlockStorageP, 
             MainC,
             LedsC,
	     HplMsp430GeneralIOC,
  	     new Msp430GpioC() as Pin60,
  	     new Msp430GpioC() as Pin61,
  	     new Msp430GpioC() as Pin62,
  	     new Msp430GpioC() as Pin34,
  	     new Msp430GpioC() as Pin35;

  
  BlockRead = BlockStorageP;
  BlockWrite = BlockStorageP;	
  BlockStorageP.Boot -> MainC;
  BlockStorageP.Leds          -> LedsC;
  
  BlockStorageP.Pin60 -> Pin60;
  BlockStorageP.Pin61 -> Pin61;
  BlockStorageP.Pin62 -> Pin62;
  BlockStorageP.Pin34 -> Pin34;
  BlockStorageP.Pin35 -> Pin35;
  
  Pin60->HplMsp430GeneralIOC.Port60;
  Pin61->HplMsp430GeneralIOC.Port61;
  Pin62->HplMsp430GeneralIOC.Port62;
  Pin34->HplMsp430GeneralIOC.Port34;
  Pin35->HplMsp430GeneralIOC.Port35;


}

