;
;**************************************************************
;*
;*        B I O S   B O O T   R O U T I N E S
;*
;**************************************************************
;

; Cold boot routine
; Not much special happens here, so it jumps directly to wboot
boot:	jp	wboot

; Warm boot routine
; Sends init signal to device bus, loads CCP, and inits CP/M
wboot:	di
	ld	sp,cbase

	; Send init signals to all devices
	ld	bc,0
wboot0:	ld	hl,bdevsw
	push	bc
	push	bc
	push	de
	call	swindir
	pop	bc
	inc	b
	ld	a,20
	cp	b
	jr	nz,wboot0

	; Load the CCP
	call	resccp
	
	; Call config init
	call	cfinit
	
	; Set up lower memory
	ld	hl,cpmlow
	ld	de,0
	ld	bc,8
	ldir
	
	jp	tm_test


; This is not a true function, but a block of code to be copied
; to CP/M lower memory
cpmlow:	jp	wboot	; should be wboot, but we want to halt
	defb	0,0
	jp	fbase


; Console status
; Defaults to device 0 right now
const:	ld	hl,cdevsw
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	or	h
	ret	z
	ld	de,3
	add	hl,de
callhl:	jp	(hl)
	
; Console read
; Defaults to device 0 right now
conin:	ld	hl,cdevsw
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	or	h
	ret	z
	ld	de,6
	add	hl,de
	jp	(hl)
	
; Console write
; Defaults to device 0 right now
conout:	ld	hl,cdevsw
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	or	h
	ret	z
	ld	de,9
	add	hl,de
	jp	(hl)
	
list:	ret
punch:	ret
reader:	ld	a,0x1A
	ret
home:	ld	bc,0
	ret
seldsk:	ld	hl,0
	ret
settrk:	ret
setsec:	ret
setdma:	ret
read:	ld	a,1
	ret
write:	ld	a,1
	ret
prstat:	ld	a,0
	ret
sectrn:	ld	h,b
	ld	l,c
	ret
	
	
; Switch indirect helper function
; Registers BC and DE should be pushed to stack
; HL will pass as argument field
; b = Device #
; c = Call Offset
; hl = Start of switch
;
; returns c=255 if device found
; uses: all
swindir:ld	d,0	; Switches must not exceed 256 bytes
	ld	e,b	; Multiply c by 4
	ld	b,d
	sla	e
	sla	e
	add	hl,de
	ld	a,(hl)	; Indirect
	inc	hl
	ld	d,(hl)
	ld	e,a
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,d
	or	e
	jr	nz,swindi1
	pop	hl	; Not found!
	pop	de	
	pop	bc
	ld	c,0
	jp	(hl)	; Return through hl
swindi1:ex	de,hl
	add	hl,bc
	ld	(callmj+1),hl
	ex	de,hl
	ld	(callarg),hl
	pop	hl
	pop	de
	pop	bc
	push	hl
	ld	hl,(callarg)
	call	callmj
	ld	c,0xFF
nulldev:ret		; Just points to a return
	
; Claims the cache, executing the sync
; command and setting the new owner
; hl = owner writeback function
chclaim:push	hl
	ld	hl,(chowner)
	call	callhl
	pop	hl
	ld	(chowner),hl
	ret
	
	
; Variables
; Small stub to jump to the memory jump register
callmj: defb	0xC3
	defw	0
; Used to shuffle around the return address during indirection
callarg:defw	0
chowner:defw	nulldev		; Current owner of the cache