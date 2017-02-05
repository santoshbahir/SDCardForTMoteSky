

includes SD;

interface SD {

  command uint8_t init ();

  command uint8_t setIdle();
  
  command uint8_t setBlockLength (const uint16_t len);
  
}
