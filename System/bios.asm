;
;**************************************************************
;*
;*        B I O S   B O O T   R O U T I N E S
;*
;**************************************************************
;
boot:	halt
	jp	boot

wboot:	jp	0
const:	jp	0
conin:	jp	0
conout:	jp	0
list:	jp	0
punch:	jp	0
reader:	jp	0
home:	jp	0
seldsk:	jp	0
settrk:	jp	0
setsec:	jp	0
setdma:	jp	0
read:	jp	0
write:	jp	0
prstat:	jp	0
sectrn:	jp	0