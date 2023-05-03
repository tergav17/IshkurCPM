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
b_cout	equ	0x02
b_print	equ	0x09
b_open	equ	0x0F
b_close	equ	0x10
b_read	equ	0x14
b_write	equ	0x15
b_make	equ	0x16
b_dma	equ	0x1A

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
	ld	hl,1024	; length of sector
	ld	c,40	; blocks per track
	ld	d,5	; sectors per track
	ld	e,40	; tracks 
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
	ld	a,c
	ld	(blkcnt),a
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
	
	cp	'W'
	jp	z,write
	
	jr	getcmd
	
; Write operation
; First, make sure user is ready
; Second, the defined file will be opened
write:	ld	c,b_print
	ld	de,readymsg
	call	bdos
	call	getopt
	cp	'Y'
	jp	nz,getpro
	
	; If there is a file, try to open it
	ld	c,b_open
	ld	de,fcb
	call	bdos
	
	; Did it work?
	or	a
	jp	p,writr
	
	; Nope, error!
	jp	ferror
	
	; Write (real)
	; Start by readying the disk
writr:	call	dskrdy

	; Set the starting track
	xor	a
	ld	(curtrk),a
	
	; Print out the current track	
writr1:	ld	c,b_print
	ld	de,fetcmsg
	call	bdos
	ld	a,(curtrk)
	ld	l,a
	ld	h,0
	call	putd
	
	; Get the track to write into memory
	ld	de,top
	ld	a,(blkcnt)
	
	; Loop to read from disk
writr2:	push	af
	push	de
	
	ld	c,b_dma
	call	bdos
	ld	c,b_read
	ld	de,fcb
	call	bdos
	
	pop	de
	pop	af
	ld	hl,128
	add	hl,de
	ex	de,hl
	dec	a
	jr	nz,writr2
	
	; Print write message
	ld	c,b_print
	ld	de,writmsg
	call	bdos
	
	; Start at sector 1
	ld	a,1
	ld	(cursec),a
	
	; Where do we want to input?
	ld	hl,top
	
	; Write the sector out
writr3:	ld	a,(nf_io)
	ld	c,a
	call	nf_wphy
	or	a
	jp	nz,nready
	
	; Do we need to read another in?
	ld	a,(seccnt)
	ld	b,a
	ld	a,(cursec)
	cp	b
	jr	z,writr4
	inc	a
	ld	(cursec),a
	jr	writr3
	
	; All done, move on to next track
writr4:	ld	a,(trkcnt)
	ld	b,a
	ld	a,(curtrk)
	inc	a
	cp	b
	jp	z,alldone	; No more tracks
	ld	(curtrk),a
	
	; Step in 1 track
	; This should be BDOS load code
	ld	a,(nf_io)
	ld	c,a
	ld	a,0x59
	out	(c),a
	call	nf_busy
	
	; Read another track
	jp	writr1
	
; Read operation
; First, make sure user is ready
; Second, the defined file will be opened (and maybe created)
read:	ld	c,b_print
	ld	de,readymsg
	call	bdos
	call	getopt
	cp	'Y'
	jp	nz,getpro

	; Alright, we are commited

	ld	a,(fcb+1)
	cp	'0'
	jp	c,ferror

	; There is a file, try to open it
	ld	c,b_open
	ld	de,fcb
	call	bdos
	
	; Did it work?
	or	a
	jp	p,readr
	ld	c,b_make
	ld	de,fcb
	call	bdos
	or	a
	jp	m,ferror
	
	; Read (real)
	; Start by readying the disk
readr:	call	dskrdy
	
	; Set the starting track
	xor	a
	ld	(curtrk),a
	
	; Print out current track
readr0:	ld	c,b_print
	ld	de,readmsg
	call	bdos
	ld	a,(curtrk)
	ld	l,a
	ld	h,0
	call	putd

	ld	a,1
	ld	(cursec),a
	
	; Where do we want to output?
	ld	hl,top
	
	; Read the sector in
readr1:	ld	a,(nf_io)
	ld	c,a
	call	nf_rphy
	or	a
	jp	nz,nready
	
	; Do we need to read another in?
	ld	a,(seccnt)
	ld	b,a
	ld	a,(cursec)
	cp	b
	jr	z,readr2
	inc	a
	ld	(cursec),a
	jr	readr1
	
	; Write track to storage and continue
readr2: ld	c,b_print
	ld	de,stormsg
	call	bdos
	
	ld	de,top
	ld	a,(blkcnt)
	
	; Loop to write to disk
readr3:	push	af
	push	de
	
	ld	c,b_dma
	call	bdos
	ld	c,b_write
	ld	de,fcb
	call	bdos
	
	pop	de
	pop	af
	ld	hl,128
	add	hl,de
	ex	de,hl
	dec	a
	jr	nz,readr3
	
	; Read next track
	ld	a,(trkcnt)
	ld	b,a
	ld	a,(curtrk)
	inc	a
	cp	b
	jr	z,alldone	; No more tracks
	ld	(curtrk),a
	
	; Step in 1 track
	; This should be BDOS load code
	ld	a,(nf_io)
	ld	c,a
	ld	a,0x59
	out	(c),a
	call	nf_busy
	
	; Read another track
	jp	readr0
	
	; Operation is done
alldone:call	nf_udsl

	; State all done!
	ld	c,b_print
	ld	de,donemsg
	call	bdos
	
	; Close file
	ld	c,b_close
	ld	de,fcb
	call	bdos
	
	jp	exit


; Reads a physical sector
; Track should be set up
; (cursec) = Sector to read
; c = FDC command address
; hl = memory location of result
;
; Returns a=0 if successful
; uses: af, bc, de, hl
nf_rphy:ld	e,c
	inc	c
	inc	c
	ld	a,(cursec)
	out	(c),a
	inc	c
	ld	d,c
	ld	c,e
	
	; Read command
	ld	a,0x88
	out	(c),a
nf_rph1:in	a,(c)
	rra	
	jr	nc,nf_rph2
	rra
	jr	nc,nf_rph1
	ld	c,d
	ini
	ld	c,e
	jr	nf_rph1
nf_rph2:in	a,(c)
	and	0xFC
	ret
	
; Writes a physical sector
; Track should be set up
; (cursec) = Sector to write
; c = FDC command address
; hl = memory location to store
;
; Returns a=0 if successful
; uses: af, bc, de, hl
nf_wphy:ld	e,c
	inc	c
	inc	c
	ld	a,(cursec)
	out	(c),a
	inc	c
	ld	d,c
	ld	c,e
	
	; Read command
	ld	a,0xA8
	out	(c),a
nf_wph1:in	a,(c)
	rra	
	jr	nc,nf_wph2
	rra
	jr	nc,nf_wph1
	ld	c,d
	outi
	ld	c,e
	jr	nf_wph1
nf_wph2:in	a,(c)
	and	0xFC
	ret


; Gets the drive ready, this means:
; 1. Force an interrupt
; 2. Make sure that there is actually a disk in the drive
; 3. Move the drive to track 0
;
; uses: af, bc, d
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
ferror:	call	nf_udsl

	ld	c,b_print
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
	
; Variables
	
iocnt:
	defb	0x00

profile:
	defb	0x00
	
seclen:
	defw	0x0000
	
seccnt:
	defb	0x00
	
blkcnt:
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
	
readymsg:	
	defb	0x0A,0x0D,'Ready to begin? (Y,N): $'

ferrmsg:	
	defb	0x0A,0x0D,'Error! Cannot open image file'
	defb	0x0A,0x0D,'Usage: FUTIL [Image file]$'
	
nfdcmsg:	
	defb	0x0A,0x0D,'Error! No FDC detected$'
	
nrdymsg:	
	defb	0x0A,0x0D,'Error! Drive Not Ready$'

readmsg:	
	defb	0x0A,0x0D,'Reading Track $'
	
stormsg:	
	defb	' Storing... $'
	
fetcmsg:	
	defb	0x0A,0x0D,'Fetching Track $'
	
writmsg:	
	defb	' Writing... $'
	
donemsg:	
	defb	0x0A,0x0D,'Operation Complete!$'


	
; Input buffer
inpbuf:	defb	0x02, 0x00, 0x00, 0x00
	
; Top of program, use it to store stuff
top: