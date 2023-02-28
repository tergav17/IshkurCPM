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
wboot:	ld	sp,cbase

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
	
infloop:jr	infloop



const:	ret
conin:	ret
conout:	ret
list:	ret
punch:	ret
reader:	ret
home:	ret
seldsk:	ret
settrk:	ret
setsec:	ret
setdma:	ret
read:	ret
write:	ret
prstat:	ret
sectrn:	ret

; Small hook to call the (HL) register
callhl:
	jp	(hl)