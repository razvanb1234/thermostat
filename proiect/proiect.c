
#include<reg51.h>
#include <stdio.h>
#define display_port P2      //Data pins connected to port 2 on microcontroller
sbit rs = P3^0;  
sbit rw = P3^1;  
sbit e =  P3^2; 
sbit lamp= P3^6;
sbit motor= P3^7;
sbit b1=P3^4;
sbit b2= P3^5;
sbit pin_1W=P1^0;
unsigned char sensorBuffer[2];
signed int temp;
float currentTemp, setTemp;

void delay(unsigned int i){
	while(i--);
}
void msdelay(unsigned int time)  // Function for creating delay in milliseconds.
{

    unsigned i,j ;

    for(i=0;i<time;i++)    

    for(j=0;j<1275;j++);
}

void lcd_cmd(unsigned char command)  //Function to send command instruction to LCD

{

    display_port = command;

    rs= 0;

    rw=0;

    e=1;

    msdelay(1);

    e=0;

}


void lcd_data(unsigned char disp_data)  //Function to send display data to LCD

{
    display_port = disp_data;
    rs= 1;
    rw=0;
    e=1;
    msdelay(1);
    e=0;
}


 void lcd_init()    //Function to prepare the LCD  and get it ready

{

    lcd_cmd(0x38);  // for using 2 lines and 5X7 matrix of LCD

    msdelay(10);

    lcd_cmd(0x0F);  // turn display ON, cursor blinking

    msdelay(10);

    lcd_cmd(0x01);  //clear screen

    msdelay(10);

    lcd_cmd(0x81);  // bring cursor to position 1 of line 1

    msdelay(10);

}
void init_1W(void)
{
    unsigned char x=0;
    pin_1W = 1;
    delay(8);
    pin_1W = 0;
    delay(80);
    pin_1W = 1;
    delay(14);
    x=pin_1W;
    delay(20);
}

unsigned char readByte_1W(void)
{
    unsigned char i=0;
    unsigned char dat = 0;
    for (i=8;i>0;i--)
    {
      pin_1W = 0;
      dat>>=1;
      pin_1W = 1;
      if(pin_1W)
      dat|=0x80;
      delay(4);
    }
    return(dat);
}

void writeByte_1W(unsigned char dat)
{
    unsigned char i=0;
    for (i=8; i>0; i--)
    {
      pin_1W = 0;
      pin_1W = dat&0x01;
      delay(5);
      pin_1W = 1;
      dat>>=1;
    }
    delay(4);
}

//temperature read for DS18B20
void read_sensor(void)
{
    init_1W();
    writeByte_1W(0xCC); //skip ROM
    writeByte_1W(0x44); //convert T
    init_1W();
    writeByte_1W(0xCC); //skip ROM
    writeByte_1W(0xBE); //read scratchpad
    sensorBuffer[0]=readByte_1W();
    sensorBuffer[1]=readByte_1W();
}


void getPress(){
	if(b1==0){
		setTemp= setTemp+1.0f;
	return;
}
	if(b2==0){
		setTemp= setTemp-1.0f;
	return;
}
}
void main()

{
		char display[33];
    int oldTemp=0;
		motor=0;
		lamp=0;
    lcd_init();
		setTemp=21.0f;
		
while(1){
	int l=0;
	int h=0;	
		read_sensor();
		temp = sensorBuffer[0]; //lsb
		temp &= 0x00FF;
		temp |= (sensorBuffer[1] << 8);
		//convert raw sensor data to temperature
		currentTemp = temp * 0.0625;
		//format line 1
		getPress();
	if (b1 == 0 || b2==0 || oldTemp!=currentTemp){
		sprintf(display, "T  = %.2f", currentTemp);
		lcd_cmd(0x01);
		lcd_cmd(0x81);
	
	while(display[l] != '\0'){
		lcd_data(display[l]);
		l++;
		msdelay(10);
	}
		lcd_cmd(0xC0);
		sprintf(display, "Set T = %.2f",setTemp);
	
	while(display[h] != '\0'){
		lcd_data(display[h]);
		h++;
		msdelay(10);
	}
}
	if(currentTemp>setTemp){
		motor=1;
		lamp=0;
	}
	else if(currentTemp<setTemp){
		motor=0;
		lamp=1;
	}
	else{
		motor=0;
		lamp=0;
	}
	oldTemp=currentTemp;
	msdelay(100);
	
	}
	}

