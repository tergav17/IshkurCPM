;
;**************************************************************
;*
;*                I S H K U R   I N I T
;*
;*      This program should run when IshkurCP/M first 
;*      starts up. It will display a hello banner and
;*      load in user settings
;*
;*      It can also be used to configure on-boot settings
;*      by running INIT after the system has booted
;*
;*	This version of INIT is for the NABU computer with
;*      TMS9918 console.
;*
;**************************************************************
;

; Equates
bdos	equ	0x0005
cmdlen	equ	0x0080
cmdarg	equ	0x0081

; Program start
	org	0x0100
	
	; Check to see if we are running for the first time
	ld	a,(cmdlen)
	cp	2
	jp	nz,config
	ld	a,(cmdarg+1)
	cp	255
	jp	nz,config
	
	; Print banner
	ld	c,0x09
	ld	de,splash
	call	bdos
	ret
		
	; Do user configuration
config:	ld	c,0x09
	ld	de,cfgmsg
	call	bdos
	
	; Get user option
	ld	c,0x0A
	ld	de,inpbuf
	call	bdos
	ld	a,(inpbuf+2)
	
	; Look for exit condition
	cp	'9'
	ret	z
	
	jr	config
	ret
	
splash:
	defb	' _____  _____ _    _ _  ___    _ _____   ',0x0A,0x0D
	defb	'|_   _|/ ____| |  | | |/ / |  | |  __ \  ',0x0A,0x0D
	defb	'  | | | (___ | |__| | | /| |  | | |__) | ',0x0A,0x0D
	defb	'  | |  \___ \|  __  |  < | |  | |  _  /  ',0x0A,0x0D
	defb	' _| |_ ____) | |  | | . \| |__| | | \ \  ',0x0A,0x0D
	defb	'|_____|_____/|_|  |_|_|\_\\____/|_|  \_\ ',0x0A,0x0D
	defb	0x0A,0x0D,'CP/M Version 2.2, Revision ALPHA',0x0A,0x0D
	defb	0x0A,0x0D,'$'

cfgmsg:
	defb	0x0A,0x0D,'ISHKUR CP/M Configuration',0x0A,0x0A,0x0D
	
	defb	'    1: Change TMS9918 Text Color',0x0A,0x0D
	defb	'    9: Exit',0x0A,0x0A,0x0D
	defb	'Option: $'
	
colmsg:
	defb	0x0A,0x0D,'TMS9918 Text Color Configuration',0x0A,0x0D
	defb	'    0: Transparent',0x0A,0x0D
	defb	'    1: Black',0x0A,0x0D
	defb	'    2: Medium Green',0x0A,0x0D
	defb	'    3: Light Green',0x0A,0x0D
	defb	'    4: Dark Blue',0x0A,0x0D
	defb	'    5: Light Blue',0x0A,0x0D
	defb	'    6: Dark Red',0x0A,0x0D
	defb	'    7: Cyan',0x0A,0x0D
	defb	'    8: Medium Red',0x0A,0x0D
	defb	'    9: Light Red',0x0A,0x0D
	defb	'    A: Dark Yellow',0x0A,0x0D
	defb	'    B: Light Yellow',0x0A,0x0D
	defb	'    C: Dark Green',0x0A,0x0D
	defb	'    D: Magenta',0x0A,0x0D
	defb	'    E: Grey',0x0A,0x0D
	defb	'    F: White',0x0A,0x0A,0x0D
	
; Input buffer
inpbuf:	defb	0x02, 0x00, 0x00, 0x00
	
; Top of program, use it to store stuff
heap: