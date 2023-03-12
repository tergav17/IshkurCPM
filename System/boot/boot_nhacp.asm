;
;**************************************************************
;*
;*        I S H K U R   F D C   B O O T S T R A P
;*
;**************************************************************
;

nsec	equ	6		; # of BDOS+BIOS sectors
mem	equ	55		; CP/M image starts at mem*1024
				; Should be same as cpm22.asm

	; NABU bootstrap loads in at 0xC000
	org	0xC000
	
; Boot start same as NABU bootstrap
; Not sure why the nops are here, but I am keeping them
base:	nop
	nop
	nop
	di
	ld	sp,base
	jr	tmsini

; Panic!
; Just jump to the start of ROM at this point
panic:	jp	0
	
	; Change TMS color mode to indicate successful boot
tmsini:	in	a,(0xA1)
	ld	a,0xE1
	out	(0xA1),a
	ld	a,0x87
	out	(0xA1),a

loop:	jr	loop
	
