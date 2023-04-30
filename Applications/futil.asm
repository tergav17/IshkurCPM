;
;**************************************************************
;*
;*       N A B U   F D C   I M A G E   U T I L I T Y
;*
;*     This utility allows for floppy disk data to be
;*     directly interacted with by the user. Disks can
;*     be imaged, formatted, or re-imaged. Both RAW track
;*     dumps and IMG sector dumps are supported
;*
;**************************************************************
;

; Equates
bdos	equ	0x0005
fcb	equ	0x005C

b_print	equ	0x09


; Program start
	org	0x0100
	
	
	; Print banner
start:	ld	c,b_print
	ld	de,splash
	call	bdos


	; Get user profile
getpro: ld	c,b_print
	ld	de,cfgmsg
	call	bdos
	call	getopt
	
	; Exit option
	cp	'9'
	jr	z,exit
	
	; Profile 1 (5.25 SSDD)
	ld	hl,1024
	ld	d,5
	ld	e,40
	cp	'1'
	jr	z,setpro


	; Invalid, reprompt
	jr	getpro

	; Soft reboot
exit:	ld	c,0x00
	jp	bdos
	
	
	; Set profile variables
setpro:	ld	(profile),a
	ld	(seclen),hl
	ld	a,d
	ld	(seccnt),a
	ld	a,e
	ld	(trkcnt),a
	
	; Now lets get the logical drive #
getcurd:ld	c,b_print
	ld	de,drvmsg
	call	bdos
	call	getopt
	
	ld	b,2
	cp	'0'
	jr	z,setcurd
	ld	b,4
	cp	'1'
	jr	z,setcurd
	jr	getcurd
	
setcurd:ld	a,b
	ld	(curdrv),a
	
	; Finally, we get the actual operation
	ld	c,b_print
	ld	de,oprmsg
	call	bdos
	call	getopt
	
	jp	exit
	
; Gets a single character option from the user
; Letters will be converted to upper case
;
; Returns character in A
; uses: all
getopt:	ld	c,0x0A
	ld	de,inpbuf
	call	bdos
	ld	a,(inpbuf+2)
	
; Converts lowercase to uppercase
; a = Character to convert
;
; Returns uppercase in A
; uses: af
ltou:	and	0x7F
	cp	0x61		; 'a'
	ret	c
	cp	0x7B		; '{'
	ret	nc
	sub	0x20
	ret
	
; Variables

profile:
	defb	0x00
	
seclen:
	defw	0x0000
	
seccnt:
	defb	0x00
	
trkcnt:
	defb	0x00
	
curdrv:
	defb	0x00
	
; Strings
	
splash:
	defb	'NABU FDC Image Utility',0x0A,0x0D
	defb	'Rev 1a, tergav17 (Gavin)',0x0A,0x0D,'$'

cfgmsg:
	defb	0x0A,0x0D,'Select a disk profile:',0x0A,0x0A,0x0D
	
	defb	'    1: NABU 5.25 SSDD (Len=1024, Sec=5, Track=40)',0x0A,0x0D
	defb	'    9: Exit',0x0A,0x0A,0x0D
	defb	'Option: $'
	
	
drvmsg:	
	defb	0x0A,0x0D,'Logical Drive # (0,1): $'
	
oprmsg:	
	defb	0x0A,0x0D,'Command ([R]ead, [W]rite, [F]ormat): $'
	
formsg:	
	defb	0x0A,0x0D,'Image format (.[R]AW,.[I]MG): $'
	
readymsg:	
	defb	0x0A,0x0D,'Ready to begin? (Y,N): $'

	
; Input buffer
inpbuf:	defb	0x02, 0x00, 0x00, 0x00
	
; Top of program, use it to store stuff
top: