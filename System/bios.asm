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
	ld	hl,bdevsw
	ld	b,16
wboot0:	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,d
	or	e
	jr	z,wboot1
	; Entry not 0, try to call it
	ld	a,(hl)
	inc	hl
	ld	l,(hl)
	ex	de,hl
	push	bc
	call	callhl
	pop	bc
	; Move on to next entry
wboot1:	pop	hl
	ld	de,4
	add	hl,de
	djnz	wboot0
	
	; Call init for all character devices
	ld	hl,(consol)
	call	callhl
	ld	hl,(printr)
	ld	a,h
	or	l
	call	nz,callhl
	ld	hl,(auxsio)
	ld	a,h
	or	l
	call	nz,callhl
	
	; Load the CCP
	call	resccp
	
	; Call config init
	call	cfinit
	
	; Set up lower memory
	ld	hl,cpmlow
	ld	de,0
	ld	bc,8
	ldir
	
	jp	cbase


; This is not a true function, but a block of code to be copied
; to CP/M lower memory
cpmlow:	jp	0	; should be wboot, but we want to halt
	defb	0,0
	jp	fbase


; Console status
; Jump to consol->init
const:	ld	hl,(consol)
	ld	de,3
	add	hl,de
	jp	(hl)
	
; Console read
; Jump to consol->read
conin:	ld	hl,(consol)
	ld	de,6
	add	hl,de
	jp	(hl)
	
; Console write
; Jump to consol->writ
conout:	push	bc
	ld	hl,(consol)
	ld	de,9
	add	hl,de
	pop	bc
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

; Small hook to call the (HL) register
callhl:
	jp	(hl)