;
;**************************************************************
;*
;*          I S H K U R   S Y S T E M   C O N F I G
;*
;*      This file contains points that should be modifed
;*      if new devices are to be added to IshkurCP/M. At
;*      a mimumum, they need to be included at the bottom
;*      of the file, and added to their appropriate dev
;*      switch. Some devices may need additional config
;*      directly in their source files
;*       
;*
;**************************************************************
;
;
;   Set memory base here. 
;
mem	equ	56		; CP/M image starts at mem*1024

;
;   General cache address
;
cache	equ	0xFC00		; Start of 1k cache memory
cache_o:defw	0		; Current owner of the cache

;
;**************************************************************
;*
;*        W A R M   B O O T   C O N F I G   H O O K
;*
;*    This function is called at the end of a warm boot
;*    to set up hardware-specific stuff. 
;*
;**************************************************************
;

cfinit:	ld	a,0x01		; Bank out ROM
	out	(0x00),a
	
	ld	a,0xC3		; Set up IRQ handler
	ld	(0x38),a	
	ld	hl,cfirq
	ld	(0x39),hl
	
	ld	a,0x0E		; Enable clock
	out	(0x41),a
	ld	a,0x10
	out	(0x40),a
	
	
	im	1		; Start interrupts
	di
	ret

;
;**************************************************************
;*
;*            I N T E R R U P T   H A N D L I N G
;*
;*     This function will be called in order to handle an
;*     interrupt if the need arises. Hooking drivers up to
;*     this code may be a little bit more involved.
;*
;**************************************************************
;

cfirq:	ei
	reti


;
;**************************************************************
;*
;*        C H A R A C T E R   D E V I C E   S W I T C H
;*
;*      Currently, 3 character devices are supported. These
;*	devices are the console, the printer, and the "punch"
;*      (can be thought of as an auxillary serial device).
;*      All character devices use the same interface
;*
;**************************************************************
;

; Device console, for user interactions with system
consol:	defw	tmsdev	; TMS9918 is console

; Printer, only the init and output functions can be used
printr:	defw	0	; nulldev

; Auxiliary SIO, interfaces with the read/punch calls
auxsio:	defw	0	; nulldev

;
;**************************************************************
;*
;*           B L O C K   D E V I C E   S W I T C H
;*
;*       IshkurCP/M can support up to 16 logical disks
;*       A single driver can be mapped to a number of
;*       these disks. Each logical disk is defined by a
;*       4-byte record. The first 2 bytes are a pointer
;*       to the device entry, and the last 2 are passed
;*       as an argument to the device. Usually this 
;*       takes the form of a minor number for indexing
;*       sub-disks on the same driver
;*
;*
;**************************************************************
;

; A device of "0" will be read as a non-existant device
; The 'init' signal can be sent to the same devices many 
; times of it has multipe entires in this table.
bdevsw:	defw	nfddev,	0	; 'A'
	defw	nfddev,	1	; 'B'
	defw	0,	0	; 'C'
	defw	0,	0	; 'D'
	defw	0,	0	; 'E'
	defw	0,	0	; 'F'
	defw	0,	0	; 'G'
	defw	0,	0	; 'H'
	defw	0,	0	; 'I'
	defw	0,	0	; 'J'
	defw	0,	0	; 'K'
	defw	0,	0	; 'L'
	defw	0,	0	; 'M'
	defw	0,	0	; 'N'
	defw	0,	0	; 'O'
	defw	0,	0	; 'P'
	
; One of the block devices needs to have the responsibiliy
; of loading the CCP into memory. Define the jump vector here
resccp:	jp	nf_ccp

; Additionally, if Ishkur is using a graphical device, that
; device may temporarily need to access the Graphical Resource
; Block (GRB) to load in fonts and such. This is up to 2k in
; size, and goes in the location that the CCP resides
resgrb:	jp	nf_grb

;
;**************************************************************
;*
;*        D E V I C E   D R I V E R   I N C L U D E S
;*
;**************************************************************
;
#include "tms9918.asm"
#include "nabu1797.asm"