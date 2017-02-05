#include "Storage.h"

module SD_log {
	provides {
		interface LogWrite;
		interface LogRead;
	}
	
	uses {
		interface Boot;
		interface Packet;
		interface BlockRead;
		interface BlockWrite;
		interface Timer<TMilli> as Timer;
		interface Leds;
  	}
}

implementation {

	char buffer[512];
	uint32_t wpointer = 0;
	uint32_t rpointer = 0;
	uint16_t currentWBlock = 0;
	uint16_t currentRBlock = 0;
	uint16_t offset[512];
	void* readbuf;
	storage_len_t readlen;

	event void Boot.booted(){

		uint16_t i;

		for(i=0;i<512;i++)
			offset[i] = 512;
	}

	event void Timer.fired(){}

	event void BlockWrite.writeDone(storage_addr_t addr, void* buf, storage_len_t len,
			       error_t error){}

	event void BlockWrite.eraseDone(error_t error){}

	event void BlockWrite.syncDone(error_t error){}

	command error_t LogWrite.append(void* buf, storage_len_t len){
		uint16_t i;

		if(len < 513){
			if(((wpointer+len)>512)){
				if(call BlockWrite.write(currentWBlock*512, buffer,512) == MMC_SUCCESS)
				offset[currentWBlock] = wpointer;
				currentWBlock++;
				wpointer = 0;
			}

			for(i = 0;i<len;i++){
				buffer[wpointer+i] = *((char*)buf + i);
			}

			wpointer += len;
			return SUCCESS;
		}
		else
			return EINVAL;
	}	

	command storage_cookie_t LogWrite.currentOffset(){}

	command error_t LogWrite.sync(){}

	command error_t LogWrite.erase(){}

	event void BlockRead.readDone(storage_addr_t addr, void* buf, storage_len_t len,error_t error){}

	event void BlockRead.computeCrcDone(storage_addr_t addr, storage_len_t len,uint16_t crc, error_t error){}

	task void readDone(){
		signal LogRead.readDone(readbuf, readlen, SUCCESS);
	}

	uint16_t getBlocks(storage_len_t len){
		uint16_t blocks = 0;
		bool moreblocks = TRUE;

		while(moreblocks){
			if((rpointer+len)>offset[currentRBlock] ){
				blocks++;
				len -= (offset[currentRBlock] - rpointer);
				rpointer = 0;
				currentRBlock++;
			}
			else{
				rpointer += len;
				moreblocks = FALSE; 
			}
		}

		return blocks;
	}

	command error_t LogRead.read(void* buf, storage_len_t len){
		char rbuffer[512];
		char tempbuffer[len];
		uint16_t i,j,nblocks,pos=0,failedblocks=0;
		uint32_t tpointer;
		uint32_t *tbuf;

		if(currentWBlock == 0 && wpointer == 0){
			return EINVAL;
		}

		else if(currentWBlock == 0){
			if(len <= wpointer){
				for(i=0;i<len;i++)
					tempbuffer[i] = buffer[i]; 		
				for(i=len,j=0;i<wpointer;i++,j++)
					buffer[j] = buffer[len];
				wpointer -= len; 
			}
			else
				return EINVAL;
		}
		else{
			tpointer = rpointer;
			nblocks = getBlocks(len);

			if(currentRBlock>currentWBlock || rpointer>offset[currentRBlock]){
				rpointer = tpointer;
				currentRBlock -=(nblocks-1);
				return EINVAL;
			}
			for(j=0;j<nblocks;j++){
				if(call BlockRead.read(j*512,rbuffer,512) == MMC_SUCCESS){
					for(i=0;i<offset[j];i++)
						tempbuffer[pos+i] = rbuffer[i];

					pos += offset[j];
				}
				else{
					failedblocks++;
				}
			}

			for(j=0;j<rpointer;j++){
				tempbuffer[pos+j] = buffer[j];
			}
		}

		buf = tempbuffer;
		readbuf = buf;
		readlen = len;
		post readDone();
		return SUCCESS;
	}

	command storage_cookie_t LogRead.currentOffset(){}

	command error_t LogRead.seek(storage_cookie_t offsetloc){}

	command storage_len_t LogRead.getSize(){}
}