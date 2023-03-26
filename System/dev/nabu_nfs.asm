;
;**************************************************************
;*
;*        N A B U   N H A C P   F I L E   S Y S T E M
;*
;*    Unlike a standard block device, the NFS driver provides
;*    a CP/M filesystem by directly intercepting system calls.
;*    By doing this, it can access provide access to an external
;*    filesystem via NHACP.
;*
;*    Virtual filesystems are directories labelled "A", "B",
;*    "C", etc... on the host system. That are converted to
;*    minor numbers 0, 1, 2, etc... when the driver is being
;*    added to the block device switch  
;* 
;**************************************************************
;

nf_ayda	equ	0x40		; AY-3-8910 data port
nf_atla	equ	0x41		; AY-3-8910 latch port
nf_hcca	equ	0x80		; Modem data port

nf_fild	equ	0x80		; Default file access desc


;
;**************************************************************
;*
;*         D U M M Y   D I S K   G E O M E T R Y
;* 
;**************************************************************
;

; Disk A DPH
nf_dpha:defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	nf_dpb	; DPB
	defw	0	; CSV
	defw	0	; ALV 
	
	
; NSHD8 format
nf_dpb:	defw	64	; # sectors per track
	defb	6	; BSH
	defb	63	; BLM
	defb	3	; EXM
	defw	1023	; DSM
	defw	255	; DRM
	defb	0x80	; AL0
	defb	0	; AL1
	defw	0	; Size of directory check vector
	defw	0	; Number of reserved tracks at the beginning of disk

; Driver entry point
; a = Command #
;
; uses: all
ndkdev:	or	a
	jr	z,nf_init
	dec	a
	dec	a
	jr	z,nf_sel
	ld	a,1
	ret

; Inits the device
; Not really needed atm
; hl = Call argument
;
; uses: none
nf_init:ret


; Selects the drive
; c = Logging status
; hl = Call argument
;
; uses: hl
nf_sel:	ret
	

; Set up the HCCA modem connection
; Configures the AY-3-8910 to monitor correct interrupts
; and leaves it in a state where the interrupt port is
; exposed
;
; uses: a
nf_hini:ld	a,0x07
	out	(nf_atla),a	; AY register = 7
	ld	a,0x7F
	out	(nf_ayda),a	; Configure AY port I/O
	
	ld	a,0x0E
	out	(nf_atla),a	; AY register = 14
	ld	a,0xC0
	out	(nf_ayda),a	; Enable HCCA receive and send
	
	ld	a,0x0F
	out	(nf_atla),a	; AY register = 15
	ret
; Loads the CCP into the CCP space
nf_ccp:	ld	hl,nf_p0
	jr	nf_grb0
	
; Loads the GRB into the CCP space
nf_grb:	ld	hl,nf_p1
nf_grb0:ld	de,nf_m0na
	ld	bc,10
	ldir			; Copy name to file open
	call	nf_hini		; Go to HCCA mode
	call	nf_open		; Open the file
	ld	de,0
	ld	hl,cbase
nf_grb1:call	nf_getb
	inc	e
	ld	a,16
	cp	e
	jr	nz,nf_grb1
	ret
	

; Open the prepared file
; Closes the existing file too
;
; uses: af, b, hl
nf_open:ld	hl,nf_m1
	ld	b,6
	call	nf_send
	ld	hl,nf_m0
	ld	b,23
	call	nf_send
	ld	hl,nf_buff
	call	nf_rece
	ret
	
; Gets a block from the currently open file
; and places it in (hl)
; de = Block to read
; hl = Destination for information
;
; Returns location directly after in hl
; Carry flag set on error
; uses: af, b, hl
nf_getb:ex	de,hl
	ld	(nf_m2bn),hl
	ex	de,hl
	push	hl
	ld	hl,nf_m2
	ld	b,12
	call	nf_send
	pop	hl
	ret	c
	call	nf_hcrd
	call	nf_hcre
	ret	c
	cp	0x84
	scf
	jr	nz,nh_get1
	call	nf_hcrd
	ld	b,128
nf_get0:call	nf_hcre
	ret	c
	ld	(hl),a
	inc	hl
	djnz	nf_get0
	or	a
	ret
nh_get1:call	nf_hcrd	; Read the error message and exit
	call	nf_hcre
	scf
	ret
	
; Puts a block into the currently open file
; from that location (hl)
; de = Block to write
; hl = Source of information
;
; Carry flag set on error
; uses: af, b, hl
nf_putb:ex	de,hl
	ld	(nf_m3bn),hl
	ex	de,hl
	push	hl
	ld	hl,nf_m3
	ld	b,12
	call	nf_send		; Send message precursor
	pop	hl
	ret	c
	ld	b,128
nf_put0:ld	a,(hl)		; Send the block
	call	nf_hcwr
	ret	c
	inc	hl
	djnz	nf_put0
	ld	hl,nf_buff
	call	nf_rece
	ld	a,(nf_buff)
	cp	0x81
	ret	z
	scf
	ret
	
; Receives a general response from the NHACP server
; hl = Destination of message
;
; Carry flag set on error
; uses: af, b, hl
nf_rece:call	nf_hcre
	ret	c		; Existing error
	ld	b,a
	call	nf_hcre
	ret	c		; Existing error
	scf
	ret	nz		; Message too big!
nf_rec0:call	nf_hcre
	ret	c		; Error!
	ld	(hl),a
	inc	hl
	djnz	nf_rec0
	or	a
	ret
	
; Write a number of bytes to the HCCA port
; b = Bytes to write
; hl = Start of message
;
; Carry flag set on error
; uses: af, b, hl
nf_send:ld	a,(hl)
	inc	hl
	call	nf_hcwr
	ret	c		; Error!
	djnz	nf_send
	ret
	
; Read from the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
;
; Returns return in a
; Carry flag set on error
; Uses: af
nf_hcrd:call	nf_hcre
nf_hcre:push	de
	ld	de,0xFFFF
nf_hcr0:in	a,(nf_ayda)
	bit	0,a
	jr	z,nf_hcr0	; Await an interrupt
	bit	1,a
	jr	z,nf_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,nf_hcr0
	scf
	ret			; Timed out waiting
nf_hcr1:in	a,(nf_hcca)
	pop	de
	or	a
	ret
	
; Write to the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
; a = Character to write
;
; Carry flag set on error
; Uses: f
nf_hcwd:call	nf_hcwr
nf_hcwr:push	de
	push	af
	ld	de,0xFFFF
nf_hcw0:in	a,(nf_ayda)
	bit	0,a
	jr	z,nf_hcw0	; Await an interrupt
	bit	1,a
	jr	nz,nf_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,nf_hcw0
	scf
	ret			; Timed out waiting
nf_hcw1:pop	af
	out	(nf_hcca),a
	pop	de
	or	a
	ret
	
; Path to CP/M image
; Total length: 10 bytes
nf_p0:	defb	'CPM22.SYS',0

; Path to GRB image
; Total length: 10 bytes
nf_p1:	defb	'FONT.GRB',0,0

; Message prototype to open a file
; Total length: 23 bytes
nf_m0:	defb	0x8F,0x00
	defw	19		; Message length
	defb	0x01		; Cmd: STORAGE-OPEN
	defb	nf_fild		; Default file descriptor
nf_m0fl:defw	0x00		; Read/Write flags
	defb	0x0E		; Message length
nf_m0na:defb	'XXXXXXXXXXXXXX'; File name field
	defb	0x00		; Padding
	
; Message prototype to close a file
; Total length: 6 bytes
nf_m1:	defb	0x8F,0x00
	defw	2		; Message length
	defb	0x05		; Cmd: FILE-CLOSE
	defb	nf_fild		; Default file descriptor
	defw	0x00		; Magic bytes
	
; Message prototype to read a block
; Total length: 12 bytes
nf_m2:	defb	0x8F,0x00
	defw	8		; Message length
	defb	0x07		; Cmd: STORAGE-GET-BLOCK
	defb	nf_fild		; Default file descritor
nf_m2bn:defw	0x00,0x00	; Block number
	defw	128		; Block length
	
; Message prototype to write a block
; Total length: 12 bytes
nf_m3:	defb	0x8F,0x00
	defw	136		; Message length
	defb	0x08		; Cmd: STORAGE-PUT-BLOCK
	defb	nf_fild		; Default file descritor
nf_m3bn:defw	0x00,0x00	; Block number
	defw	128		; Block length

; Variables
nf_buff	equ	nf_bss		; Buffer (64b)