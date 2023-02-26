;
;**************************************************************
;*
;*        I S H K U R   F D C   B O O T S T R A P
;*
;**************************************************************
;


	; NABU bootstrap loads in at 0xC000
	org	0xC000
	
	; Boot start same as NABU bootstrap
base:	nop
	nop
	nop
	di
	ld	sp,base
	
	; Change TMS color mode to indicate successful boot
	
	in	a,(0xA1)
	ld	a,0xE1
	out	(0xA1),a
	ld	a,0x87
	out	(0xA1),a
	
	; loop endlessly
loop:
	halt
	jp	loop
