;
;**************************************************************
;*
;*       N A B U   F D C   I M A G E   U T I L I T Y
;*
;*     This utility allows for floppy disk data to be
;*     directly interacted with by the user. Disks can
;*     be imaged, formatted, or re-imaged. At the moment,
;*     only .IMG style images are supported.
;*
;**************************************************************
;

; Equates
bdos	equ	0x0005
fcb	equ	0x005C

b_coin	equ	0x01
b_print	equ	0x09
b_open	equ	0x0F
b_make	equ	0x16

; Program start
	org	0x0100
	
	
	; Print banner
start:	ld	c,b_print
	ld	de,splash
	call	bdos

	; Look for the FDC
	ld	c,0xCF
search:	in	a,(c)
	cp	0x10
	jr	z,foundit
	inc	c
	jr	z,nofdc
	ld	a,0x0F
	add	a,c
	ld	c,a
	jr	search
	
	; No FDC found!
nofdc:	ld	c,b_print
	ld	de,nfdcmsg
	call	bdos
	jp	waitex
	
	; Place address in nf_io, and get the user profile
foundit:ld	a,c
	sub	15
	ld	c,a
	ld	(nf_io),a

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
	ld	(nf_curd),a
	
	; Finally, we get the actual operation
getcmd:	ld	c,b_print
	ld	de,cmdmsg
	call	bdos
	call	getopt
	
	cp	'R'
	jp	z,read
	
	jr	getcmd
	
; Read operation
; First, the defined file be opened
; Then the user will be prompted for what image type they want
read:	ld	a,(fcb+1)
	cp	'0'
	jp	c,ferror

	; There is a file, try to open it
	ld	c,b_open
	ld	de,fcb
	call	bdos
	
	; Did it work?
	or	a
	jp	p,readty
	ld	c,b_make
	ld	de,fcb
	call	bdos
	or	a
	jp	m,ferror
	
	; Get image type for read
readty:	ld	c,b_print
	ld	de,formsg
	call	bdos
	call	getopt
	
	cp	'R'
	jr	z,readr
	
	jr	readty
	
	; Read raw
	; Make sure user is ready
readr:	ld	c,b_print
	ld	de,readymsg
	call	bdos
	call	getopt
	cp	'Y'
	jp	nz,getpro
	
	; Alright, we are commited
	; Start by reading the disk
	call	dskrdy
	
	; Read in a track
readr0:	ld	a,(nf_io)
	ld	c,a	; c = nf_io
	ld	e,a	; e = nf_io
	add	a,3
	ld	d,a	; d = nf_io+3
	ld	a,0xE0
	out	(c),a 
	ld	hl,top
	
	; Read loop
readr1:	in	a,(c)
	bit	1,a
	jr	nz,readr2
	bit	0,a
	jr	z,readr3
	or	a
	jp	nz,nready
	jr	readr1
	
	; Read a bit from the disk
readr2:	ld	c,d
	in	a,(c)
	ld	(hl),a
	inc	hl
	ld	c,e
	jr	readr1
	
	; Operation done
readr3:	jr	readr3


; Gets the drive ready, this means:
; 1. Force an interrupt
; 2. Make sure that there is actually a disk in the drive
; 3. Move the drive to track 0
dskrdy:	ld	d,255
	call	nf_dvsc
	ld	a,(nf_io)
	ld	c,a
	ld	a,0xD0
	out	(c),a		; Force FDC interrupt
dskrdy0:call	nf_stal
	in	a,(c)
	and	0x02
	jr	nz,dskrdy1
	dec	d
	jr	nz,dskrdy0
	
	; No disk!
nready:	call	nf_udsl
	
	ld	c,b_print
	ld	de,nrdymsg
	call	bdos
	jr	waitex

	; Found disk
	; Restore to track 0
dskrdy1:ld	a,(nf_io)
	ld	c,a
	ld	a,0x09
	out	(c),a 
	call	nf_busy
	
	ret

; "Handle" a file error
; Complain to user and exit out
ferror:	ld	c,b_print
	ld	de,ferrmsg
	call	bdos
	
waitex:	ld	c,b_coin
	call	bdos
	
	jp	exit
	
; Selects or deselects a drive
; a = Drive density / selection
;
; uses: af
nf_dvsc:ld	a,(nf_curd)	; Select current drive
	jr	nf_dvsl
nf_udsl:xor	a		; Unselects a drive
nf_dvsl:push	bc
	ld	b,a
	ld	a,(nf_io)
	add	a,0x0F
	ld	c,a
	out	(c),b
	ld	b,0xFF
	call	nf_stal
	pop	bc
	ret
	
; Waits until FDC is not busy
; c = FDC command address
;
; uses: af
nf_busy:in	a,(c)
	rra
	jr	c,nf_busy
	ret
	
; Waits a little bit
;
; uses: b
nf_stal:push	bc
	pop	bc
	djnz	nf_stal
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
	
; Variables

iobuf:
	defw	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defw	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defw	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defw	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	
iocnt:
	defb	0x00

profile:
	defb	0x00
	
seclen:
	defw	0x0000
	
seccnt:
	defb	0x00
	
trkcnt:
	defb	0x00
	
nf_curd:
	defb	0x00
	
nf_io:
	defb	0x00
	
curtrk:
	defb	0x00
	
cursec:
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
	
cmdmsg:	
	defb	0x0A,0x0D,'Command ([R]ead, [W]rite, [F]ormat): $'
	
formsg:	
	defb	0x0A,0x0D,'Image format (.[R]AW,.[I]MG): $'
	
readymsg:	
	defb	0x0A,0x0D,'Ready to begin? (Y,N): $'

ferrmsg:	
	defb	0x0A,0x0D,'Error! Cannot open image file'
	defb	0x0A,0x0D,'Usage: FUTIL [Image file]$'
	
nfdcmsg:	
	defb	0x0A,0x0D,'Error! No FDC detected$'
	
nrdymsg:	
	defb	0x0A,0x0D,'Error! Drive Not Ready$'



	
; Input buffer
inpbuf:	defb	0x02, 0x00, 0x00, 0x00
	
; Top of program, use it to store stuff
top: