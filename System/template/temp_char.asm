;
;**************************************************************
;*
;*      T E M P L A T E   C H A R A C T E R   D E V I C E
;*
;*      Boilerplate for a character device
;* 
;**************************************************************
;
; BSS Segment Variables
.area	_BSS

; Any variable defined here will default to '0x00' on a warm boot
; Its size will count towards the total allocated memory, but not the image size
tc_exam:defs	1	; Example variable

.area	_TEXT


; Driver jump table 
tmcdev:	or	a
	jr	z,tc_init
	dec	a
	jr	z,tc_stat
	dec	a
	jr	z,tc_read
	jr	tc_writ
	
; Device init
; hl = Call argument
;
; uses: none
tc_init:ret

; Device status 
;
; Returns a=0xFF if there is a character to read, a=0x00 otherwise
; hl = Call argument
;
; uses: af
tc_stat:xor	a
	ret
	
; Waits for a character to come in and returns it
; hl = Call argument
;
; Returns ASCII key in A
; uses: af
tc_read:xor	a
	ret
	
; Writes a character to the device
; c = Character to write
; hl = Call argument
;
; uses: none
tc_writ:ret
	