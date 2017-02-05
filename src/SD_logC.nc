configuration SD_logC {
	provides{		
		interface LogWrite;
		interface LogRead;
	}
}
implementation {
  components BlockStorageC, 
	     SD_log,
             MainC,
             new TimerMilliC() as Timer,
             LedsC;

  LogWrite = SD_log;
  LogRead = SD_log;
  SD_log.Boot -> MainC;
  SD_log.Timer         -> Timer;
  SD_log.Leds          -> LedsC;
  SD_log.BlockWrite ->  BlockStorageC;
  SD_log.BlockRead  ->  BlockStorageC;  
}