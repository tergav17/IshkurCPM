;
;**************************************************************
;*
;*       N A B U   I D E   S Y S T E M   G E N E R A T E
;*
;*     This utility is used to format and prepare an attached
;*     IDE drive to be booted off of. The user can format the
;*     drive, and then write a bootsector, font GRB, and
;*     image onto the disk.
;*
;**************************************************************
;

; Equates
bdos	equ	0x0005
fcb	equ	0x005C

b_coin	equ	0x01
b_cout	equ	0x02
b_print	equ	0x09
b_open	equ	0x0F
b_close	equ	0x10
b_read	equ	0x14
b_write	equ	0x15
b_make	equ	0x16
b_dma	equ	0x1A

id_base	equ	0xC0

; Program start
	org	0x0100
	
	
	; Print banner
start:	di	
	ld	c,b_print
	ld	de,splash
	call	bdos

	; Get system image
getsys: ld	c,b_print
	ld	de,cfgmsg
	call	bdos
	call	getopt
	
	; Exit option
	cp	'9'
	ret	z
	
	; System Option #1
	ld	hl,0	; pointer to image
	cp	'1'
	jr	z,setsys


	; Invalid, reprompt
	jr	getsys
	
	; Set system image
setsys:	ld	(sysimg),hl

	; Now lets get the logical drive #
getcurd:ld	c,b_print
	ld	de,drvmsg
	call	bdos
	call	getopt
	
	ld	b,0xE0
	cp	'0'
	jr	z,setcurd
	ld	b,0xF0
	cp	'1'
	jr	z,setcurd
	jr	getcurd
	
setcurd:ld	a,b
	ld	(curdrv),a

	; Format option
	ld	c,b_print
	ld	de,formmsg
	call	bdos
	call	getopt
	ld	(doform),a
	
	; Ready to begin?
	ld	c,b_print
	ld	de,readymsg
	call	bdos
	call	getopt
	cp	'Y'
	jp	nz,getsys
	
	; Begin operation, check to made sure drive is present
	ld	a,(curdrv)
	out	(id_base+0xC),a
	ld	b,255
	call	stall
	in	a,(id_base+0xC)
	inc	a
	jr	nz,format
	
	; Error!
	ld	c,b_print
	ld	de,noderror
	call	bdos
	xor	a
	out	(id_base+0xC),a
	jp	0
	
	; Do a format?
format:	call	id_busy
	ld	a,(doform)
	cp	'Y'
	jp	nz,sysgen
	
	ld	c,b_print
	ld	de,fnowmsg
	call	bdos
	
	ret
	
	
	; Generate system onto disk
sysgen:	
	
; Waits for a DRQ (Data Request)
;
; uses: af
id_wdrq:in	a,(id_base+0xE)
	bit	3,a
	jr	z,id_wdrq
	ret
	
; Issues an IDE command
; a = Command to issue
;
; uses: af
id_comm:push	af
	call	id_busy
	pop	af
	out	(id_base+0xE),a
	ret
	
	
; Waits for the IDE drive to no longer be busy
id_busy:in	a,(id_base+0xE)
	bit	6,a
	jr	z,id_busy
	bit	7,a
	jr	nz,id_busy
	ret
	
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
	
; Print decimal
; hl = value to print
;
; uses: all
putd:	ld	d,'0'
	ld	bc,0-10000
	call	putd0
	ld	bc,0-1000
	call	putd0
	ld	bc,0-100
	call	putd0
	ld	bc,0-10
	call	putd0
	ld	bc,0-1
	dec	d
putd0:	ld	a,'0'-1		; get character
putd1:	inc	a
	add	hl,bc
	jr	c,putd1
	sbc	hl,bc
	ld	b,a
	cp	d		; check for leading zeros
	ret	z
	dec	d
	
	; Actually print character out
	push	bc
	push	de
	push	hl
	ld	e,b
	ld	c,b_cout
	call	bdos
	pop	hl
	pop	de
	pop	bc
	ret
	
; Waits a little bit
; b = Number of cycles to stall for
;
; uses: b
stall:  push	bc
	pop	bc
	djnz	stall
	ret
	
; Variables
	
sysimg:
	defw	0
	
curdrv:
	defb	0

doform:
	defb	0

; Strings
	
splash:
	defb	'NABU IDE SysGen Utility',0x0A,0x0D
	defb	'Rev 1a, tergav17 (Gavin)',0x0A,0x0D,'$'

cfgmsg:
	defb	0x0A,0x0D,'Select a System Image:',0x0A,0x0A,0x0D
	
	defb	'    1: IshkurCP/M IDE + NFS',0x0A,0x0D
	defb	'    9: Exit',0x0A,0x0A,0x0D
	defb	'Option: $'
	
	
drvmsg:	
	defb	0x0A,0x0D,'Logical Drive # (0,1): $'

formmsg:	
	defb	0x0A,0x0D,'Format Disk? (Y,N): $'
	
readymsg:	
	defb	0x0A,0x0D,'Ready to begin? (Y,N): $'

fnowmsg:	
	defb	0x0A,0x0D,'Formatting Drive Now... $'


noderror:	
	defb	0x0A,0x0D,'Error: No Disk Detected!$'
	
donemsg:	
	defb	0x0A,0x0D,'Operation Complete!$'


	
; Input buffer
inpbuf:	defb	0x02, 0x00, 0x00, 0x00
	
; Top of program, use it to store stuff
top: