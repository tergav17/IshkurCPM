;
;**************************************************************
;*
;*        I S H K U R   F D C   B O O T S T R A P
;*
;**************************************************************
;

nsec	equ	4		; # of BDOS+BIOS sectors
mem	equ	58		; CP/M image starts at mem*1024
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
; Set the screen to red and loop 
panic:	in	a,(0xA1)
	ld	a,0x96
	out	(0xA1),a
	ld	a,0x87
	out	(0xA1),a
panic1:	jp	panic1	
	
	; Change TMS color mode to indicate successful boot
tmsini:	in	a,(0xA1)
	ld	a,0xE1
	out	(0xA1),a
	ld	a,0x87
	out	(0xA1),a

	; Look for the FDC
	ld	c,0xCF
findfd:	in	a,(c)
	cp	0x10
	jr	z,drsel
	inc	c
	jp	z,panic
	ld	a,0x0F
	add	a,c
	ld	c,a
	jr	findfd

	; FDC has been found, select drive
drsel:	ld	a,2
	out	(c),a
	ld	b,0xFF
	call	stall
	
	; Get command register
	ld	a,c
	sub	0x0F
	ld	c,a
	ld	(fdaddr),a
	
	; Force FDC interrupt
	ld	a,0xD0
	out	(c),a
	ld	b,0x10
	call	stall
	
	; Restore to track 0
	; We should already be there, but just in case :)
	ld	a,0x09
	out	(c),a
	call	fdbusy
	
	; Step in 1 track
	; This should be the start of the BDOS
	ld	a,0x59
	out	(c),a
	call	fdbusy
	
	; Time to read in a sector
	; Set the sector register
	ld	hl,1024*(mem+2)
reads:	ld	a,(cursec)
	inc	c
	inc	c
	out	(c),a
	ld	d,c
	inc	d
	dec	c
	dec	c
	
	; Issue read command
	ld	a,0x88
	out	(c),a
	ld	b,0x10
	call	stall
	
	; Wait for data to show up
dwait:	in	a,(c)
	or	a
	rra
	jr	nc,nexts
	rra
	jr	c,dread
	or	a
	jr	nc,dwait
	jr	panic
dread:	ld	b,c		; Data is here, read it in
	ld	c,d
	ini
	inc	b
	ld	c,b
	jr	dwait
	
	; Move on to the next sector
nexts:	ld	a,(cursec)
	cp	nsec
	
	; If all sectors are in, jump to image
	
	jp	z,9+1024*(mem+2)
	inc	a
	ld	(cursec),a
	jr	reads
	
	
; Waits a little bit
;
; uses: b
stall:	djnz	stall
	ret
	
; Waits until FDC is not busy
; c = FDC command address
;
; uses: a
fdbusy:	in	a,(c)
	rra
	jr	c,fdbusy
	ret

; Variables
fdaddr:	defb	0	; FDC address
cursec:	defb	1	; Current sector
