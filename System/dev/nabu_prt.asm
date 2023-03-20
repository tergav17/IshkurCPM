;
;**************************************************************
;*
;*        N A B U   P A R A L L E L   O U T P U T
;*
;*      A simple output-only device driver for the NABU
;*      parellel printer port. 
;* 
;**************************************************************
;

pr_ayda	equ	0x40		; AY-3-8910 data port
pr_atla	equ	0x41		; AY-3-8910 latch port
pr_prnt	equ	0xB0		; Parallel output
pr_ctrl	equ	0x00		; Device control register

; Driver jump table 
prtdev:	or	a
	jr	z,pr_init
	dec	a
	jr	z,pr_stat
	dec	a
	jr	z,pr_read
	jr	pr_writ
	
; Device init
; Does nothing
;
; uses: none
pr_init:ret

; Device status 
; There are never any characters to read
;
; Returns a=0xFF if there is a character to read
; uses: af
pr_stat:xor	a
	ret
	
; Waits for a character to come in and returns it
; No characters to read, returns 0
;
; Returns ASCII key in A
; uses: af
pr_read:xor	a
	ret
	
; Writes a character to the device
; c = Character to write
;
; uses: af, bc
pr_writ:ld	a,0x0F
	out	(pr_atla),a	; AY register = 15
	
pr_wri0:in	a,(pr_ayda)	; Wait for not busy
	and	0x10
	jr	nz,pr_wri0
	
	ld	a,c
	out	(pr_prnt),a	; Write data
	
	ld	a,0x05		; Strobe
	out	(pr_ctrl),a
	
	ld	b,32		
pr_wri1:djnz	pr_wri1		; Wait a few cycles
	
	ld	a,0x01		; Strobe off
	out	(pr_ctrl),a
	
	ret
	