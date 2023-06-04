;
;**************************************************************
;*
;*        N A B U   N H A C P   V I R T U A L   D I S K
;*
;*     This driver allows for IshkurCP/M to access a virtual
;*     disk using the NHACP protocol. Indiviual files are 
;*     mounted as file systems and accessed like a disk
;*     normally would.
;*
;*     This particular driver uses the Nabu HCCA port to 
;*     facilitate communication between it and an adapter
;*
;*     In order to service CCP and GRB requests, the 
;*     following special files must exist:
;*
;*     '${STORAGE}/CPM22.SYS' <- For CP/M system components
;*     '${STORAGE}/FONT.GRB' <- For graphical driver components
;*
;*
;*
;*
;*     Device requires 384 bytes of bss space (nd_bss)
;* 
;**************************************************************
;
; BSS Segment Variables
.area	_BSS
nd_tran:defs	1	; Transfer count
nd_csec:defs	1	; Current sector (1b)
nd_ctrk:defs	2	; Current track (2b)
nd_buff:defs	64	; Buffer (64b)
nd_asva:defs	129	; ASV #1 (129b)
nd_asvb:defs	129	; ASV #1 (129b)
.area	_TEXT

nd_ayda	equ	0x40		; AY-3-8910 data port
nd_atla	equ	0x41		; AY-3-8910 latch port
nd_hcca	equ	0x80		; Modem data port
nd_nctl	equ	0x00		; NABU control port

nd_fild	equ	0x80		; Default file access desc


;
;**************************************************************
;*
;*         D I S K   D R I V E   G E O M E T R Y
;* 
;**************************************************************
;

; Disk A DPH
nd_dpha:defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	nd_dpb	; DPB
	defw	0	; CSV
	defw	nd_asva	; ALV (129 bytes)
	
; Disk B DPH
nd_dphb:defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	nd_dpb	; DPB
	defw	0	; CSV
	defw	nd_asvb	; ALV (129 bytes)
	
; NSHD8 format
nd_dpb:	defw	64	; # sectors per track
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
	jr	z,nd_init
	dec	a
	jr	z,nd_home
	dec	a
	jr	z,nd_sel
	dec	a
	jp	z,nd_strk
	dec	a
	jp	z,nd_ssec
	dec	a
	jp	z,nd_read
	jp	nd_writ
	
; Inits the device
; Not really needed atm
; hl = Call argument
;
; uses: none
nd_init:ret

; Sets "track" back to zero
;
; uses: none
nd_home:ld	hl,0
	ld	(nd_ctrk),hl
	ret

; Selects the drive
; c = Logging status
; hl = Call argument
;
; uses: hl
nd_sel:	push	hl
	call	nd_hini
	pop	hl
	push	hl
	ld	a,l
	add	a,0x41		; Convert to ASCII
	ld	(nd_p2im),a
	ld	hl,nd_p2
	ld	de,nd_m0na
	ld	bc,11
	ldir
	call	nd_open		; Open the file
	pop	hl		; Select DPH
	ld	a,l
	or	a
	ld	hl,nd_dpha
	ret	z
	dec	a
	ld	hl,nd_dphb
	ret	z
	ld	hl,0
	ret
	
; Sets the track of the selected block device
; bc = Track, starts at 0
; hl = Call argument
;
; uses: nonoe
nd_strk:ld	h,b
	ld	l,c
	ld	(nd_ctrk),hl
	ret

; Sets the sector of the selected block device
; bc = Sector, starts at 0
; hl = Call argument
;
; uses: none
nd_ssec:ld	a,c
	ld	(nd_csec),a
	ret

; Reads a sector and DMA transfers it to memory
;
; uses: af
nd_read:call	nd_hini
	call	nd_gbno
	ld	hl,(biodma)
	call	nd_getb
	ld	a,1
	ret	c
	xor	a
	ret
	
; Write a sector from DMA
;
; uses: af
nd_writ:call	nd_hini
	call	nd_gbno
	ld	hl,(biodma)
	call	nd_putb
	ld	a,1
	ret	c
	xor	a
	ret
	
	
; Gets the block # for read / write operations
;
; Returns block # in de
; uses: af, de, hl 
nd_gbno:ld	hl,(nd_ctrk)
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	a,(nd_csec)
	or	l
	ld	l,a
	ex	de,hl
	ret
	

; Set up the HCCA modem connection
; Configures the AY-3-8910 to monitor correct interrupts
; and leaves it in a state where the interrupt port is
; exposed
;
; uses: a, b
nd_hini:ld	a,0x07
	out	(nd_atla),a	; AY register = 7
	ld	a,0x7F
	out	(nd_ayda),a	; Configure AY port I/O
	
	; Claim interrupt vectors
	push	hl
	ld	hl,nd_rirq
	ld	(intvec),hl
	ld	hl,nd_wirq
	ld	(intvec+2),hl
	pop	hl
	
; Set interrupts to their default state
;
; uses: a
nd_dflt:ld	a,0x0E
	out	(nd_atla),a	; AY register = 14
	ld	a,0xB0
	out	(nd_ayda),a	; Enable HCCA receive and but not send, plus key and VDP
	
nd_dfl0:ld	a,0x0F		
	out	(nd_atla),a	; AY register = 15
	
	ret

; Set receive and send interrupts
;
; uses: a
nd_esnd:ld	a,0x0E
	out	(nd_atla),a	; AY register = 14
	ld	a,0xC0
	out	(nd_ayda),a	; Enable HCCA receive and send
	jr	nd_dfl0
	
; Set receive but not send interrupt
;
; uses: a
nd_dsnd:ld	a,0x0E
	out	(nd_atla),a	; AY register = 14
	ld	a,0x80
	out	(nd_ayda),a	; Enable HCCA receive and but not send
	jr	nd_dfl0


; Loads the CCP into the CCP space
nd_ccp:	ld	hl,nd_p0
	jr	nd_grb0
	
; Loads the GRB into the CCP space
nd_grb:	ld	hl,nd_p1
nd_grb0:ld	de,nd_m0na
	ld	bc,10
	ldir			; Copy name to file open
	call	nd_hini		; Go to HCCA mode
	ld	hl,0x0000	; O_RDONLY
	call	nd_opef		; Open the file
	ld	de,0
	ld	hl,cbase
nd_grb1:call	nd_getb
	inc	e
	ld	a,16
	cp	e
	jr	nz,nd_grb1
	ret
	

; Open the prepared file
; Closes the existing file too
;
; uses: af, b, hl
nd_open:ld	hl,0x0001	; O_RDWR
nd_opef:ld	(nd_m0fl),hl
	ld	hl,nd_m1
	ld	b,6
	call	nd_send
	ld	hl,nd_m0
	ld	b,23
	call	nd_send
	ld	hl,nd_buff
	call	nd_rece
	ret
	
; Gets a block from the currently open file
; and places it in (hl)
; de = Block to read
; hl = Destination for information
;
; Returns location directly after in hl
; Carry flag set on error
; uses: af, b, hl
nd_getb:call	nd_get0
	jp	nd_dflt
nd_get0:ex	de,hl
	ld	(nd_m2bn),hl
	ex	de,hl
	push	hl
	ld	hl,nd_m2
	ld	b,12
	call	nd_send
	pop	hl
	ret	c
	call	nd_hcrd
	call	nd_hcre
	ret	c
	cp	0x84
	scf
	jr	nz,nd_get2
	call	nd_hcre
	ld	(nd_tran),a
	ld	b,a
	call	nd_hcre
	ld	a,b
	or	a
	ret	z
nd_get1:call	nd_hcre
	ret	c
	ld	(hl),a
	inc	hl
	djnz	nd_get1
	or	a
	ret
nd_get2:call	nd_hcrd	; Read the error message and exit
	call	nd_hcre
	scf
	ret
	
; Puts a block into the currently open file
; from that location (hl)
; de = Block to write
; hl = Source of information
;
; Carry flag set on error
; uses: af, b, hl
nd_putb:call	nd_put0
	jp	nd_dflt
nd_put0:ex	de,hl
	ld	(nd_m3bn),hl
	ex	de,hl
	push	hl
	ld	hl,nd_m3
	ld	b,12
	call	nd_send		; Send message precursor
	pop	hl
	ret	c
	ld	b,128
nd_put1:ld	a,(hl)		; Send the block
	call	nd_hcwr
	ret	c
	inc	hl
	djnz	nd_put1
	ld	hl,nd_buff
	call	nd_rece
	ld	a,(nd_buff)
	cp	0x81
	ret	z
	scf
	ret
	
; Receives a general response from the NHACP server
; hl = Destination of message
;
; Carry flag set on error
; uses: af, b, hl
nd_rece:call	nd_rec0
	jp	nd_dflt
nd_rec0:call	nd_hcre
	ret	c		; Existing error
	ld	b,a
	call	nd_hcre
	ret	c		; Existing error
	scf
	ret	nz		; Message too big!
nd_rec1:call	nd_hcre
	ret	c		; Error!
	ld	(hl),a
	inc	hl
	djnz	nd_rec1
	or	a
	ret
	
; Write a number of bytes to the HCCA port
; b = Bytes to write
; hl = Start of message
;
; Carry flag set on error
; uses: af, b, hl
nd_send:ld	a,(hl)
	inc	hl
	call	nd_hcwr
	ret	c		; Error!
	djnz	nd_send
	ret
	
; Read from the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
;
; Returns result in a
; Carry flag set on error
; Uses: af
nd_hcrd:call	nd_hcre
nd_hcre:push	de
	ld	a,0x09
	out	(nd_nctl),a	; Turn on recv light
	ld	de,0xFFFF
nd_hcr0:ld	a,(nd_inf)
	or	a
	jr	nz,nd_hcr2
	in	a,(nd_ayda)
	;bit	0,a
	;jr	z,nd_hcr0	; Await an interrupt
	;bit	1,a
	;jr	z,nd_hcr1
	and	0x0F
	xor	0b00000001
	jr	z,nd_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,nd_hcr0
nd_hcer:ld	a,0x01
	out	(nd_nctl),a	; Turn off recv light
	scf
	pop	de
	ret			; Timed out waiting
nd_hcr1:ld	a,0x01
	out	(nd_nctl),a	; Turn off recv light
	in	a,(nd_hcca)
	pop	de
	or	a
	ret
nd_hcr2:ld	a,0x01
	out	(nd_nctl),a	; Turn off recv light
	xor	a
	ld	(nd_inf),a
	ld	a,(nd_inb)
	pop	de
	ret
	
; HCCA read interrupt
; Reads from the HCCA, buffers it, and then sets the flag
;
; uses: none
nd_rirq:push	af
	in	a,(nd_hcca)
	ld	(nd_inb),a
	ld	a,1
	ld	(nd_inf),a
	pop	af
	ei
	ret
	
	
; Write to the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
; a = Character to write
;
; Carry flag set on error
; Uses: f
nd_hcwr:push	de
	ld	(nd_outb),a
	xor	a
	ld	(nd_outf),a
	call	nd_esnd
	ld	de,0xFFFF
	ld	a,0x21
	out	(nd_nctl),a	; Turn on send light
nd_hcw0:ld	a,(nd_outf)
	or	a
	jr	nz,nd_hcw2
	in	a,(nd_ayda)
	;bit	0,a
	;jr	z,nd_hcw0	; Await an interrupt
	;bit	1,a
	;jr	nz,nd_hcw1
	and	0x0F
	xor	0b00000011
	jr	z,nd_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,nd_hcw0
	call	nd_dsnd
	jr	nd_hcer		; Timed out waiting
nd_hcw1:ld	a,(nd_outb)
	out	(nd_hcca),a
nd_hcw2:pop	de
	ld	a,0x01
	out	(nd_nctl),a	; Turn off send light
	call	nd_dsnd
	or	a
	ret
	
; HCCA write interrupt
; Writes to the HCCA from the buffer, and 
nd_wirq:push	af
	ld	a,(nd_outb)
	out	(nd_hcca),a
	ld	a,1
	ld	(nd_outf),a
	call	nd_dsnd		; Y'all can't behave, turning off
	pop	af
	ei
	ret
	
; Byte to send out of HCCA
nd_outb:defb	0

; HCCA output flag
nd_outf:defb	0

; Byte received from HCCA
nd_inb:	defb	0

; HCCA input flag
nd_inf: defb	0
	
; Path to CP/M image
; Total length: 10 bytes
nd_p0:	defb	'CPM22.SYS',0

; Path to GRB image
; Total length: 10 bytes
nd_p1:	defb	'FONT.GRB',0,0

; Path to a generic disk image
; Total length: 11
nd_p2:	defb	'NDSK_'
nd_p2im:defb	'?'		; Disk image name
	defb	'.IMG',0

; Message prototype to open a file
; Total length: 23 bytes
nd_m0:	defb	0x8F,0x00
	defw	19		; Message length
	defb	0x01		; Cmd: STORAGE-OPEN
	defb	nd_fild		; Default file descriptor
nd_m0fl:defw	0x01		; Read/Write flags
	defb	0x0E		; Message length
nd_m0na:defb	'XXXXXXXXXXXXXX'; File name field
	defb	0x00		; Padding
	
; Message prototype to close a file
; Total length: 6 bytes
nd_m1:	defb	0x8F,0x00
	defw	2		; Message length
	defb	0x05		; Cmd: FILE-CLOSE
	defb	nd_fild		; Default file descriptor
	defw	0x00		; Magic bytes
	
; Message prototype to read a block
; Total length: 12 bytes
nd_m2:	defb	0x8F,0x00
	defw	8		; Message length
	defb	0x07		; Cmd: STORAGE-GET-BLOCK
	defb	nd_fild		; Default file descritor
nd_m2bn:defw	0x00,0x00	; Block number
	defw	128		; Block length
	
; Message prototype to write a block
; Total length: 12 bytes
nd_m3:	defb	0x8F,0x00
	defw	136		; Message length
	defb	0x08		; Cmd: STORAGE-PUT-BLOCK
	defb	nd_fild		; Default file descritor
nd_m3bn:defw	0x00,0x00	; Block number
	defw	128		; Block length
