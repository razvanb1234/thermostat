org 0000h

; LCD pins
LCD_PORT equ P2
LCD_E equ P3.2
LCD_RS equ P3.0

; OneWire pin
PIN_1W equ  P1.0

; Heater relay pin
PIN_RELAY equ P3.7

; Keyboard pins
KEY_DEC equ P3.5
KEY_INC equ P3.4

; Timer consts for generic 8051 for 1 ms delay
INIT_TL0 equ 017h
INIT_TH0 equ 0FCh

; Sensor data buffer start address
SENSOR_DATA_BUFFER equ 030h

; Set temperature buffer start address
SET_TEMP_BUFFER equ 032h

; Display buffer start address
DISP_BUFFER_L1 equ 034h
DISP_BUFFER_L2 equ 045h

org 0000h

sjmp main

text1:
db "T     = ", 0
text2:
db "Set T = ", 0

main:

; I/O pins initialization
mov LCD_PORT, #0
clr LCD_E
clr LCD_RS
clr PIN_RELAY
setb KEY_DEC
setb KEY_INC

; Set temperature buffer initialization (21 degrees)
; Set temperature is represented as raw sensor data
mov r0, #SET_TEMP_BUFFER
mov @r0, #01010000b
inc r0
mov @r0, #00000001b

; Timer initialization
; Timer0 used for delay
orl TMOD, #00010001b
anl TMOD, #11111101b
mov P0, #0

; Display initialization
acall lcd_init

main_loop:
	acall read_sensor
	; copy sensor data to buffer
	mov r0, #SENSOR_DATA_BUFFER
	mov a, r1
	mov @r0, a
	mov a, r2
	inc r0
	mov @r0, a

	 ; clear LCD
	mov a, #01h
	clr LCD_RS
	acall lcd_send_byte

	; Copy constant text for line 1
	mov r0, #DISP_BUFFER_L1
	mov dptr, #text1
	setb LCD_RS
	acall lcd_copy_buffer

	; Convert sensor data to ASCII
	acall convert_int_temp
	acall to_ascii
	acall load_int_disp_buffer

	acall convert_frac_temp
	acall to_ascii
	acall load_frac_disp_buffer
	mov @r0, #0

	; Display line 1
	mov r0, #DISP_BUFFER_L1
	acall lcd_send_chars_ram ; display current temperature

	; Load set temperature to registers for conversion
	mov r0, #SET_TEMP_BUFFER
	mov a, @r0
	mov r1, a
	inc r0
	mov a, @r0
	mov r2, a

	; Move to line 2
	mov a, #0C0h
	clr LCD_RS
	acall lcd_send_byte

	; Copy constant text for line 1
	mov r0, #DISP_BUFFER_L2
	mov dptr, #text2
	acall lcd_copy_buffer

	; Convert set temperature to ASCII
	acall convert_int_temp
	acall to_ascii
	acall load_int_disp_buffer

	acall convert_frac_temp
	acall to_ascii
	acall load_frac_disp_buffer
	mov @r0, #0

	; Display line 2
	mov r0, #DISP_BUFFER_L2
	acall lcd_send_chars_ram

	; Read keyboard
	acall get_keys
	
	; Compare set and current temperature and enable relay if
	; current temperature is lower
	acall compare_temp

	; Wait 100 ms
	mov r3, #100
	delay:
		acall delay_1ms
		djnz r3, delay
	sjmp main_loop
; end of main loop



delay_1ms:
	; load initial timer values
	mov TL0, #INIT_TL0
	mov TH0, #INIT_TH0
	; enable timer
	setb TR0
	; wait for overflow
	wait:
		jnb TF0, wait
	; disable timer
	clr TR0
	; clear overflow flag
	clr TF0
	ret

simple_delay:
	djnz r7, simple_delay
	ret

init_1W:
	setb PIN_1W
	mov r7, #48
	acall simple_delay

	clr PIN_1W

	mov r7, #180
	acall simple_delay
	mov r7, #180
	acall simple_delay

	setb PIN_1W

	mov r7, #84
	acall simple_delay

	jnb PIN_1W, init_error
	init_error:
		orl 06h, #1
		jmp init_end
	anl 06h, #0FEh
	init_end:
	mov r7, #20
	acall simple_delay
	ret

; Result in accumulator
read_byte_1W:
	mov r6, #8
	clr a
	start_read:
		clr PIN_1W
		clr C
		rrc a
		setb PIN_1W
		jnb PIN_1W, read_end
		orl a, #080h
		read_end:
			mov r7, #30
			acall simple_delay
		djnz r6, start_read
	ret

; Write byte from accumulator
write_byte_1W:
	mov r6, #8
	start_write:
		clr PIN_1W
		rrc a
		mov PIN_1W, C
		mov r7, #45
		acall simple_delay
		setb PIN_1W
		djnz r6, start_write
	mov r7, #30
	acall simple_delay
	ret

; Read temperature from DS18B20 sensor
read_sensor:
	acall init_1W
	; TODO : handle error
	mov a, #0CCh ; skip ROM
	acall write_byte_1W
	mov a, #044h ; convert T
	acall write_byte_1W
	acall init_1W
	mov a, #0CCh ; skip ROM
	acall write_byte_1W
	mov a, #0BEh ; read Scratchpad
	acall write_byte_1W
	acall read_byte_1W
	mov r1, a
	acall read_byte_1W
	mov r2, a
	ret

lcd_send_byte:
	anl LCD_PORT, #0Fh
	mov r7, a
	anl a, #0F0h
	mov b, LCD_PORT
	anl b, #0Fh
	orl a, b
	mov LCD_PORT, a
	mov a, r7
	setb LCD_E

	acall delay_1ms

	clr LCD_E

	mov r7, #4
	lcd_cmd_wait:
		acall delay_1ms
		djnz r7, lcd_cmd_wait

	anl LCD_PORT, #0Fh
	mov r7, #4
	lcd_shift:
		clr c
		rlc a
		djnz r7, lcd_shift
	anl a, #0F0h
	mov b, LCD_PORT
	anl b, #0Fh
	orl a, b
	mov LCD_PORT, a
	setb LCD_E

	acall delay_1ms

	clr LCD_E
	mov r7, #4
	lcd_cmd_wait2:
		acall delay_1ms
		djnz r7, lcd_cmd_wait2
	ret

lcd_init:
	clr LCD_RS
	mov a, #02h ; 4 bit mode
	acall lcd_send_byte
	mov a, #028h ; 5x7 chars
	acall lcd_send_byte
	mov a, #0Eh ; cursor on
	acall lcd_send_byte
	mov a, #01h ; clear
	acall lcd_send_byte
	mov a, #080h ; move cursor to first position
	acall lcd_send_byte
	ret

; Copies data from code memory pointed by dptr to RAM pointed by r0
; Stops at null terminator
lcd_copy_buffer:
	lcd_copy_loop:
		clr a
		movc a, @a+dptr
		jz lcd_copy_stop
		mov @r0, a
		inc r0
		inc dptr
		sjmp lcd_copy_loop
	lcd_copy_stop:
	ret

; Prints data pointed by r0 on LCD
; Stops at null terminator
lcd_send_chars_ram:
	setb LCD_RS
	lcd_send_chars_ram_loop:
		mov a, @r0
		jz lcd_send_ram_stop
		acall lcd_send_byte
		inc r0
		sjmp lcd_send_chars_ram_loop
	lcd_send_ram_stop:
	ret

; Raw sensor data from r0 and r1 is converted to absolute value
; of temperature (integer part only) stored in a
; if temperature is negative, PSW^1 is set
convert_int_temp:
	mov a, r2
	anl a, #080h
	clr PSW^1
	jnz conv_int_neg_temp
	sjmp conv_int_pos_temp
	conv_int_neg_temp:
	setb PSW^1 ; used to display '-'
	mov a, r1
	cpl a
	clr c
	inc a
	mov r1, a
	mov a, r2
	cpl a
	addc a, #0
	mov r2, a
	conv_int_pos_temp:
	mov a, r2
	mov r3, #4
	convert_int_temp_loop:
		clr c
		rlc a
		djnz r3, convert_int_temp_loop
	mov b, a
	mov a, r1
	mov r3, #4
	convert_int_temp_loop2:
		clr c
		rrc a
		djnz r3, convert_int_temp_loop2
	orl a, b
	ret

; Raw sensor data from r0 is converted to fractional part of temperature
; with two decimal digits stored in a
convert_frac_temp:
	mov a, r1
	anl a, #0Fh
	mov b, #6
	mul ab
	ret

; Values in a and b are converted to ascii by adding '0'
to_ascii:
	mov b, #10
	div ab
	add a, #'0'
	mov r7, a
	mov a, b
	add a, #'0'
	mov b, a
	mov a, r7
	ret

; Stores integer temperature part in display buffer
load_int_disp_buffer:
	jb PSW^1, disp_minus
	sjmp skip
	disp_minus:
	mov r3, a
	mov a, #'-'
	mov @r0, a
	inc r0
	mov a, r3
	skip:
	mov @r0, a
	inc r0
	mov @r0, b
	inc r0
	ret

; Stores fractional part in display buffer
load_frac_disp_buffer:
	mov @r0, #'.'
	inc r0
	mov @r0, a
	inc r0
	mov @r0, b
	inc r0
	ret


get_keys:
	setb KEY_INC
	setb KEY_DEC
	jb KEY_INC, get_key_dec
	
	; Increase temperature key pressed
	mov r3, #10
	delay_inc:
		acall delay_1ms
		djnz r3, delay_inc
	jb KEY_INC, get_key_end
	mov r0, #SET_TEMP_BUFFER
	mov a, @r0
	clr c
	add a, #8
	mov @r0, a
	inc r0
	mov a, @r0
	addc a, #0
	mov @r0, a
	ret
	get_key_dec:
	jb KEY_DEC, get_key_end
	
	; Decrease temperature key pressed
	mov r3, #10
	delay_dec:
		acall delay_1ms
		djnz r3, delay_dec
	jb KEY_DEC, get_key_end
	mov r0, #SET_TEMP_BUFFER
	mov a, @r0
	clr c
	subb a, #8
	mov @r0, a
	inc r0
	mov a, @r0
	subb a, #0
	mov @r0, a
	get_key_end:
	ret

; Substract : set - current
compare_temp:
	; substract lsb
	mov r0, #SENSOR_DATA_BUFFER
	mov a, @r0
	mov b, a
	mov r0, #SET_TEMP_BUFFER
	mov a, @r0
	clr c
	subb a, b
	
	;substract_msb
	mov r0, #SENSOR_DATA_BUFFER+1
	mov a, @r0
	mov b, a
	mov r0, #SET_TEMP_BUFFER+1
	mov a, @r0
	subb a, b
	cpl c
	mov PIN_RELAY, c
	ret
	

cmnd:
mov p2, a
clr P3.2
clr P3.3
setb P3.4
clr P3.4
acall delaay
acall delaay
ret

dataa:
mov p2, a
setb P3.2
clr P3.3
setb P3.4

clr p3.4
acall delaay
acall delaay
ret

delaay:
mov r7, #0ffh
repeta:
nop
nop
nop
nop
nop
djnz r7, repeta
nop
ret
end
	









