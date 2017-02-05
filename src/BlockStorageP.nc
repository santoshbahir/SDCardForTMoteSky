#include "SD.h"
includes SD;

#define CS_LOW()   	call Pin62.clr()
#define CS_HIGH()  	call Pin62.set()	


module BlockStorageP {
	provides {
		interface SD;
		interface BlockRead;
		interface BlockWrite;
	}

	uses {
		interface Boot;
		interface Leds;
		interface GeneralIO as Pin60;
		interface GeneralIO as Pin61;
		interface GeneralIO as Pin62;
		interface GeneralIO as Pin34;
		interface GeneralIO as Pin35;
	}
}

implementation {

	typedef struct sd_block_state_t {
		uint32_t addr;
		void* buf;
		uint32_t len;
	} sd_block_state_t;

	sd_block_state_t SDBlock_req;
	bool isBusy=FALSE;		

	uint8_t spiSendByte (uint8_t);
	void sendCmd(const uint8_t, uint32_t, const uint8_t);
	uint8_t getResponse();
	uint8_t getXXResponse(const uint8_t);
	uint8_t checkBusy();


	event void Boot.booted(){
		call SD.init();

	}


	command error_t BlockRead.computeCrc(storage_addr_t addr, storage_len_t len, uint16_t crc){
		//We are calculating the CRC; Hence directly signaling and returning success.
		signal BlockRead.computeCrcDone(addr, len, 0xFF, SUCCESS);
		return SUCCESS;
	}

	task void syncdone(){
		signal BlockWrite.syncDone(SUCCESS);
	}

	command error_t  BlockWrite.sync(){
		//Everything is already in sync; so signaling and returning success.
		post syncdone();
		return SUCCESS;
	}


	command uint8_t SD.init(){
		int i;

		// Port Expansion Port Function        	Dir     
		// Pin        3.4-Dout  - UART0TX       	Out     
		// Pin        3.5-Din   - UART0RX       	Inp    
		// Pin        6.1-Clk   - ADC1       	Out   
		// Pin        6.2-CS - ADC2       	Out       0 - Active 1 - none Active

		call Pin60.makeOutput();	 
		call Pin61.makeOutput();	
		call Pin62.makeOutput();
		call Pin34.makeOutput();
		call Pin35.makeInput();		

		call Pin61.clr();			

		//initialization sequence on PowerUp

		CS_LOW();

		for(i=0;i<9;i++)
		{
			spiSendByte(0xff);
		}
		return call SD.setIdle();
	}


	uint8_t spiSendByte (uint8_t data){
		uint8_t response =0;
		atomic{
			uint32_t i;

			for(i=0;i<8;i++){
				if((data & 0x80) != 0) {
					call Pin34.set();
				}
				else{ 
					call Pin34.clr();	
				}

				data = data << 1;
				call Pin61.set();	
				response = response << 1;

				if(call Pin35.get()) {
					response |= 0x01;
				}


				call Pin61.clr();	
			}
		}
		return (response);
	}


	command uint8_t SD.setIdle(){
		char response=0x01;

		CS_LOW();
		// Intiate SPI mode

		sendCmd(SD_GO_IDLE_STATE, 0, 0x95);

		// confirm that card is READY 
		if((response = getResponse()) != 0x01)
			return SD_INIT_ERROR;
		
		do{
			CS_HIGH();
			spiSendByte(0xff);
			CS_LOW();
			sendCmd(SD_SEND_OP_COND, 0x00, 0xff);
		}while((response = getResponse()) == 0x01);

		CS_HIGH();
		spiSendByte(0xff);

		return SD_SUCCESS;
	}


	void sendCmd(const uint8_t cmd, uint32_t data, const uint8_t crc){
		uint8_t frame[6];
		register int8_t i;

		frame[0] = cmd | 0x40;
		for(i = 3; i >= 0; i--)
			frame[4 - i] = (uint8_t)(data >> (8 * i));

		frame[5] = crc;

		for(i = 0; i < 6; i++)
			spiSendByte(frame[i]);
	}


	uint8_t getResponse()
	{
		register int i=0;
		uint8_t response =0;

		for(i = 0; i < 65; i++){
			if(((response = spiSendByte(0xff)) == 0x00) | (response == 0x01)){
				break;
			}
		}
		return response;
	}


	uint32_t getBlocks(uint32_t dataoffset,uint32_t len){

		uint32_t blocks = 1;
		bool moreblocks = TRUE;

		while(moreblocks){

			if((dataoffset+len)>512 ){
				blocks++;
				len -= (512-dataoffset);
				dataoffset = 0;
			}
			else{
				moreblocks = FALSE;
			}
		}

		return blocks;
	}


	task void SDWrite(){
		register uint16_t i,k;
		error_t rvalue = EINVAL;         

		uint32_t count = SDBlock_req.len;
		uint32_t address = SDBlock_req.addr ;
		void *buffer = SDBlock_req.buf;			

		uint32_t datablock = address/512;
		uint32_t dataoffset = address%512;	
		uint32_t nblocks = getBlocks(dataoffset,count);	
		uint8_t  tempbuf[512];

		if(call SD.setBlockLength (512) == SD_SUCCESS){   

			uint32_t curlen,pos=0;
			for(k=0;k<nblocks;k++){		

				if(dataoffset + count> 512){
					curlen = 512 - dataoffset;
				}
				else{
					curlen = count;
				}
				count -= curlen;	

				CS_LOW ();

				// Read the data present in the block into a buffer

				sendCmd(SD_READ_SINGLE_BLOCK, (datablock+k)*512 , 0xff);

				// check if the SD Card acknowledged the read block command

				if(getResponse() == 0x00){
					// Wait for some duration for data token to signify the start of the data
					if(getXXResponse(SD_START_DATA_BLOCK_TOKEN) == SD_START_DATA_BLOCK_TOKEN){

						// Data Bytes
						for (i = 0; i < 512; i++)
							tempbuf[i] = spiSendByte(0xff);   

						//  CRC bytes 
						spiSendByte(0xff);
						spiSendByte(0xff);
						rvalue = SUCCESS;
					}
				}

				// Overwrite the data in the buffer with the 
				//data received for writing at appropriate position

				for(i=0;i<curlen;i++)
					tempbuf[i+dataoffset] = *((uint8_t*)buffer + i + pos);

				pos += curlen; 
	
				// Request SD card for the write operation

				sendCmd(SD_WRITE_BLOCK,( datablock+k)*512, 0xff);

				// check if the SD Card acknowledged the write block command

				if(getXXResponse(SD_R1_RESPONSE) == SD_R1_RESPONSE){
					spiSendByte(0xff);

					// send the data token to signify the start of the data
					spiSendByte(0xfe);


					for(i = 0; i < 512; i++)
						spiSendByte(tempbuf[i]);            

					// CRC bytes 
					spiSendByte(0xff);
					spiSendByte(0xff);


					checkBusy();

					rvalue = SUCCESS;
				}

				dataoffset = 0;
			}
		}

		CS_HIGH ();

		// Send 8 Clock pulses of delay.
		spiSendByte(0xff);
		isBusy = FALSE;
		signal BlockWrite.writeDone(address, buffer, count, rvalue);
	}

	command error_t BlockWrite.write(uint32_t address, void * buffer,uint32_t count){
		if(!isBusy){	
			isBusy = TRUE;
			SDBlock_req.addr = address;
			SDBlock_req.buf = buffer;
			SDBlock_req.len = count;


			post SDWrite();
			return SUCCESS;
		}
		return EBUSY;
	}

	command uint8_t SD.setBlockLength (const uint16_t len) {
		CS_LOW ();

		sendCmd(SD_SET_BLOCKLEN, len, 0xff);

		if(getResponse() != 0x00){
			call SD.init();
			sendCmd(SD_SET_BLOCKLEN, len, 0xff);
			getResponse();
		}


		CS_HIGH ();

		// Send 8 Clock pulses of delay.
		spiSendByte(0xff);

		return SD_SUCCESS;
	}


	uint8_t getXXResponse(const uint8_t resp){
		register uint32_t i;
		uint8_t response;

		for(i = 0; i < 1001; i++){
			if((response = spiSendByte(0xff)) == resp)
			{
				break;
			}
		}
		return response;
	}


	uint8_t checkBusy(){
		register uint8_t i, j;
		uint8_t response, rvalue;

		for(i = 0; i < 65; i++){
			response = spiSendByte(0xff);
			response &= 0x1f;
			switch(response){

				case 0x05: 
				rvalue = SD_SUCCESS;
				break;
				case 0x0b: 
				return SD_CRC_ERROR;
				case 0x0d: 
				return SD_WRITE_ERROR;
				default:
				rvalue = SD_OTHER_ERROR;
				break;
			}

			if(rvalue == SD_SUCCESS)
				break;
			}

			for(j = 0; j < 512; j++){

				if(spiSendByte(0xff)){
					break;
			}
		}

		return response;
	}


	task void SDRead(){
		register uint32_t i = 0,k,pos=0;

		uint32_t address=SDBlock_req.addr;
		void* buffer=SDBlock_req.buf;
		uint32_t count=SDBlock_req.len;

		uint8_t rvalue = EINVAL;


		uint32_t datablock = address/512;
		uint32_t dataoffset = address%512;
		uint32_t nblocks = getBlocks(dataoffset,count);
		uint8_t  tempbuf[512];

		// Set the block length to read
		if(call SD.setBlockLength(512) == SD_SUCCESS){   // block length can be set


			uint32_t curlen;
			for(k=0;k<nblocks;k++){


				if(dataoffset + count> 512){
					curlen = 512 - dataoffset;
				}
				else{
					curlen = count;
				}
				count -= curlen;




				CS_LOW ();
				sendCmd(SD_READ_SINGLE_BLOCK, (datablock+k)*512, 0xff);

				// check if the SD Card acknowledged the read block command

				if(getResponse() == 0x00){
					if(getXXResponse(SD_START_DATA_BLOCK_TOKEN) == SD_START_DATA_BLOCK_TOKEN){
						for (i = 0; i < 512; i++)
							tempbuf[i] = spiSendByte(0xff);   

						//  CRC bytes 
						spiSendByte(0xff);
						spiSendByte(0xff);
						rvalue = SUCCESS;
					}
				}

				// Read the data read from the block into correct position in buffer			
				for(i=0;i<curlen;i++)
					*((uint8_t*)buffer + pos + i) = tempbuf[i+dataoffset];
				pos = curlen;
				dataoffset = 0;

			}
		}

		CS_HIGH ();
		spiSendByte(0xff);
		isBusy = FALSE;
		signal BlockRead.readDone(SDBlock_req.addr, buffer, SDBlock_req.len, rvalue);
	}

	command uint8_t BlockRead.read(uint32_t address,void* buffer, uint32_t count){

		if(!isBusy){
			isBusy = TRUE;
			SDBlock_req.addr=address;
			SDBlock_req.buf=buffer;
			SDBlock_req.len=count;
			post SDRead();
			return SUCCESS;
		}
			return EBUSY;
	}

	command uint32_t BlockRead.getSize(){
		// Read contents of Card Specific Data (CSD)

		uint32_t SD_CardSize = 0;
		uint16_t i, j, b, response, sd_C_SIZE;
		uint8_t sd_READ_BL_LEN, sd_C_SIZE_MULT;

		CS_LOW ();

		sendCmd(SD_READ_CSD,0,0xff);   // CMD 9




		if(getResponse() == 0x00){


			if(getXXResponse(SD_START_DATA_BLOCK_TOKEN) == SD_START_DATA_BLOCK_TOKEN){


				for(j = 0; j < 5; j++)          
					b = spiSendByte(0xff);


				b = spiSendByte(0xff);  
				sd_READ_BL_LEN = b & 0x0f;

				b = spiSendByte(0xff);

				sd_C_SIZE = (b & 0x03) << 10;

				b = spiSendByte(0xff);
				sd_C_SIZE += b << 2;

				b = spiSendByte(0xff);

				sd_C_SIZE += b >> 6;


				b = spiSendByte(0xff);


				sd_C_SIZE_MULT = (b & 0x03) << 1;
				b = spiSendByte(0xff);
				sd_C_SIZE_MULT += b >> 7;

				for(j=0;j<9;j++)
					b = spiSendByte(0xff);



				b = spiSendByte(0xff);
				CS_LOW ();

				SD_CardSize = (sd_C_SIZE + 1);
				for(i = 2, j = sd_C_SIZE_MULT + 2; j > 1; j--)
					i <<= 1;

				SD_CardSize *= i;

				for(i = 2,j = sd_READ_BL_LEN; j > 1; j--)
					i <<= 1;

				SD_CardSize *= i;

			}
		}

		return SD_CardSize;
	}


	task void SDErase(){
		uint8_t rvalue = EINVAL;
		CS_LOW ();

		sendCmd(SD_TAG_SECTOR_START,0*512, 0xff);

		if(getResponse() == 0x00){
			CS_HIGH();
			spiSendByte(0xff);
			CS_LOW();

			sendCmd(SD_TAG_SECTOR_END,25*512, 0xff);

			if(getResponse() == 0x00){
				CS_HIGH();
				spiSendByte(0xff);
				CS_LOW();

				sendCmd(SD_EREASE, 0, 0xff);


				if(getResponse() == 0x00){
					if(getXXResponse(0xff) == 0xff){
						rvalue = SUCCESS;
					}
				}
			}
		}

		CS_HIGH();

		signal BlockWrite.eraseDone(rvalue);
	}

	command error_t BlockWrite.erase(){
		post SDErase(); 
		return SUCCESS;
	}
}
