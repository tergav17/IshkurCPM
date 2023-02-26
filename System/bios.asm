;
;**************************************************************
;*
;*        B I O S   B O O T   R O U T I N E S
;*
;**************************************************************
;

; Cold boot routine
; Not much special happens here, so it jumps directly to wboot
boot:	jp	boot

; Warm boot routine
; Sends wboot signal to device bus, loads CCP, and inits CP/M
wboot:	



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