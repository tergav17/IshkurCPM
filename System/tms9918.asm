;
;**************************************************************
;*
;*      T M S 9 9 1 8   C H A R A C T E R   D E V I C E
;*
;*      This device emulated a VT52 terminal using the
;*      TMS9918A graphics chip. The 2kb font record is
;*      not resident is memory, and must be provided by
;*      a compatable        
;* 
;**************************************************************
;

; Driver jump table
tmsdev:	jp	tm_init
	jp	tm_stat
	jp	tm_read
	jp	tm_writ
	
; TMS9918 Init
; Load font record, set up terminal
tm_init:ret


tm_stat:ret


tm_read:ret


tm_writ:ret