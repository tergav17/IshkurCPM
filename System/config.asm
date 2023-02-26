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
mem	equ	58		; CP/M image starts at mem*1024


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

; A device of "0" will be read as a non-existant devic 
bdevsw:	defw	0,	0	; 'A'
	defw	0,	0	; 'B'
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

;
;**************************************************************
;*
;*        D E V I C E   D R I V E R   I N C L U D E S
;*
;**************************************************************
;
#include "tms9918.asm"