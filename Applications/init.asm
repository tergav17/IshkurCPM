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
fcb	equ	0x005C
cmdlen	equ	0x0080
cmdarg	equ	0x0081

tm_data	equ	0xA0	; TMS9918 data register (mode=0)
tm_latc	equ	0xA1	; TMS9918 latch register (mode=1)


; Program start
	org	0x0100
	
	; Check to see if we are running for the first time
	ld	a,(cmdlen)
	cp	2
	jp	nz,config
	ld	a,(cmdarg+1)
	cp	255
	jp	nz,config
	
	; Attempt to find INIT.INI
	call	openini
	jp	z,banner	; Can't open, just exit
	
	call	docfg

	; Print banner
banner:	ld	c,0x09
	ld	de,splash
	call	bdos

	ret
	
; Actually does the configuration
docfg:	call	setdma
	ld	c,0x14
	ld	de,fcb
	call	bdos		; Read file
	
	call	setcol		; Set color
	ret
		
	; Do user configuration
	; Attempt to load INIT.INI
config:	call	openini
	jp	z,cretini	; Can't open, create it!
	
	call	docfg
	
prompt:	ld	c,0x09
	ld	de,cfgmsg
	call	bdos
	
	; Get user option
	ld	c,0x0A
	ld	de,inpbuf
	call	bdos
	ld	a,(inpbuf+2)
	
	; Do commands?
	cp	'1'
	jp	z,cfgcol
	
	; Look for exit condition
	cp	'9'
	jp	z,save
	
	jr	prompt
	ret
	
	; Create the ini file
cretini:call	setf
	ld	c,0x16
	call	bdos
	
	; Default values
	ld	a,0xE1		; Default color
	ld	(tsmcol),a
	
	jp	prompt
	
	; Save the file and exit
save:	call	openini
	call	setdma
	ld	c,0x15
	ld	de,fcb
	call	bdos
	
	; Close and exit
	ld	c,0x10
	ld	de,fcb
	jp	bdos
	
	; Configure colors
cfgcol:	ld	c,0x09
	ld	de,colmsg
	call	bdos
	
	; Do foreground color
fgcol:	ld	c,0x09
	ld	de,formsg
	call	bdos
	
	; Get user option
	ld	c,0x0A
	ld	de,inpbuf
	call	bdos
	ld	a,(inpbuf+2)
	sub	'A'
	cp	16
	jr	nc,fgcol
	rlca
	rlca
	rlca
	rlca
	ld	b,a
	push	bc
	
	; Do background color
bgcol:	ld	c,0x09
	ld	de,bacmsg
	call	bdos
	
	; Get user option
	ld	c,0x0A
	ld	de,inpbuf
	call	bdos
	ld	a,(inpbuf+2)
	sub	'A'
	cp	16
	jr	nc,bgcol
	pop	bc
	or	b
	
	ld	(tsmcol),a
	call	setcol
	jp	prompt
	
	
; Sets the TMS9918 color 
setcol:	in	a,(tm_latc)
	ld	a,(tsmcol)
	out	(tm_latc),a
	ld	a,0x87
	out	(tm_latc),a
	ret
	
; Sets the FCB for a file open or creation
;
; Returns FCB in DE
; uses: af, bc, de, hl 
setf:	ld	hl,inifile
	ld	de,fcb
	push	de
	ld	bc,16
	ldir
	xor	a
	ld	(fcb+0x20),a
	pop	de
	ret
	
; Attempt to open the ini file
;
; Returns z if failed
; uses: all
openini:call	setf
	ld	c,0x0F
	call	bdos
	inc	a
	ret
	
; Set DMA to top of memory
setdma:	ld	de,top
	ld	c,0x1A
	jp	bdos
	
; Strings

; File prototype
; Length: 16 bytes
inifile:
	defb	0,'INIT    INI',0,0,0,0
	
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
	defb	'    A: Transparent',0x0A,0x0D
	defb	'    B: Black',0x0A,0x0D
	defb	'    C: Medium Green',0x0A,0x0D
	defb	'    D: Light Green',0x0A,0x0D
	defb	'    E: Dark Blue',0x0A,0x0D
	defb	'    F: Light Blue',0x0A,0x0D
	defb	'    G: Dark Red',0x0A,0x0D
	defb	'    H: Cyan',0x0A,0x0D
	defb	'    I: Medium Red',0x0A,0x0D
	defb	'    J: Light Red',0x0A,0x0D
	defb	'    K: Dark Yellow',0x0A,0x0D
	defb	'    L: Light Yellow',0x0A,0x0D
	defb	'    M: Dark Green',0x0A,0x0D
	defb	'    N: Magenta',0x0A,0x0D
	defb	'    O: Grey',0x0A,0x0D
	defb	'    P: White',0x0A,0x0D,'$'
	
formsg:	
	defb	0x0A,0x0D,'Foreground Color: $'
bacmsg:	
	defb	0x0A,0x0D,'Background Color: $'
	
	
; Input buffer
inpbuf:	defb	0x02, 0x00, 0x00, 0x00
	
; Top of program, use it to store stuff
top:
tsmcol	equ	top	; TMS9918 Color