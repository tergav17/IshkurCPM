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
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,d
	and	e
	jr	z,wboot1
	
	
	
wboot1:



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