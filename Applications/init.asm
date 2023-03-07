;
;**************************************************************
;*
;*                I S H K U R   I N I T
;*
;*      This program should run when IshkurCP/M first 
;*      starts up. It will display a hello banner and
;*      load in user settings
;*
;**************************************************************
;

bdos	equ	0x0005

	org	0x0100
	
	; Print banner
	ld	c,0x09
	ld	de,splash
	call	bdos
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