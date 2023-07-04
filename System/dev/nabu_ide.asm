;
;**************************************************************
;*
;*          N A B U   I D E   D I S K   D R I V E R
;*
;*    Interfaces a generic IDE device to the NABU. Capacity
;*    of the drive must be at least 32MB, and cannot be ATAPI.
;*    At the moment, only usage of the master drive is supported,
;*    but the drive is split up into four 8MB "partitions" that
;*    act as seperate disks.
;* 
;**************************************************************
;
; BSS Segment Variables
.area	_BSS

id_curd:defs	1	; Currently selected disk
id_subs:defs	1	; Current subsector
id_inco:defs	1	; Set if sector is in core already
id_dirt:defs	1	; Set if cache is dirty

id_csec:defs	1	; Current sector (1b)
id_ctrk:defs	2	; Current track (2b)

id_cach:defs	512	; Sector cache

.area	_NOINIT

id_alva:defs	128	; ALV #1 (128b)
id_alvb:defs	128	; ALV #2 (128b)
id_alvc:defs	128	; ALV #3 (128b)
id_alvd:defs	128	; ALV #4 (128b)

.area	_TEXT

id_rdsk	equ	0xE0	; Defines which drives contains system
			; resources (0xE0 = Master, 0xF0 = Slave)
			
id_base	equ	0xC0
;
;**************************************************************
;*
;*         D I S K   D R I V E   G E O M E T R Y
;* 
;**************************************************************
;

; Disk A DPH
id_dpha:
	defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	id_dpb	; DPB
	defw	0	; CSV
	defw	id_alva	; ALV

; Disk B DPH
id_dphb:
	defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	id_dpb	; DPB
	defw	0	; CSV
	defw	id_alvb	; ALV
	
; Disk C DPH
id_dphb:
	defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	id_dpb	; DPB
	defw	0	; CSV
	defw	id_alvc	; ALV
	
; Disk D DPH
id_dphb:
	defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	id_dpb	; DPB
	defw	0	; CSV
	defw	id_alvd	; ALV

; NSHD8 modifed format
id_dpb:	defw	64	; # sectors per track
	defb	6	; BSH
	defb	63	; BLM
	defb	3	; EXM
	defw	1021	; DSM
	defw	255	; DRM
	defb	0x80	; AL0
	defb	0	; AL1
	defw	0	; Size of directory check vector
	defw	2	; Number of reserved tracks at the beginning of disk


; Driver entry point
; a = Command #
;
; uses: all
idedev:	or	a
	jr	z,id_init
	dec	a
	jr	z,id_home
	dec	a
	jr	z,id_sel
	dec	a
	jp	z,id_strk
	dec	a
	jp	z,id_ssec
	dec	a
	jp	z,id_read
	jp	id_writ
	
; Initialize device
; Not needed in current implementation
id_init:ret

; Sets "track" back to zero
;
; uses: hl
id_home:call	id_wdef
	ld	hl,0
	ld	(id_ctrk),hl
	jp	id_sbno
	
; Selects the drive
; c = Logging status
; hl = Call argument
;
; uses; all
id_sel:	call	id_wdef		; Write back if needed
	ld	a,0xE0
	bit	2,l
	jr	z,id_sel0
	ld	a,0xF0
	
	; Set either master or slave
id_sel0:out	(id_base+0xC),a
	ld	b,10
	call	id_stal
	
	; Is there actually a disk here?
	ld	b,l
	ld	hl,0
	in	a,(id_base+0xC)
	inc	a
	ret	z
	
	; What subdisk are we using?
	ld	a,0x03
	and	b
	push	af
	rrca
	rrca
	ld	(id_curd),a
	pop	af
	
	; Upgrade this code to a jump table maybe?
	ld	hl,id_dpha
	or	a
	ret	z
	ld	hl,id_dphb
	dec	a
	ret	z
	ld	hl,id_dphc
	dec	a
	ret	z
	ld	hl,id_dphd
	ret
	

; Sets the track of the selected block device
; bc = Track, starts at 0
; hl = Call argument
;
; uses: all
id_strk:ld	hl,(id_ctrk)
	or	a
	sbc	hl,bc
	ret	z
	call	id_wdef
	ld	(id_ctrk),bc
	jr	id_sbno

; Sets the sector of the selected block device
; bc = Sector, starts at 0
; hl = Call argument
;
; uses: all
id_ssec:ld	a,(id_csec)
	xor	c
	and	0xFC
	ld	(id_csec),a
	ret	z	; No effective change!
	call	id_wdef
	;	Fallt o id_gbno
	
; Sets the IDE registers to point at the current geometric block
;
; Returns block # in de
; uses: af, de, hl 
id_sbno:ld	hl,(nd_ctrk)
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
	
; Sets up the IDE registers to the new
	
; Ensure sector is in core, and set up for DMA transfer
;
; uses: all
id_rdwr:ld	a,(id_inco)
	or	a
	jr	nz,id_rdw0
	
	; Read in to cache
	call	id_dvsc
	ld	a,(id_io)
	ld	c,a
	ld	hl,id_cach
	call	id_rphy
	ld	b,a
	call	id_udsl
	ld	a,b
	
	; Error checking
	or	a
	ld	a,1
	ret	nz
	ld	(id_inco),a
	
	; DMA subsector
id_rdw0:ld	hl,(biodma)
	ex	de,hl

	ld	a,(id_subs)
	ld	hl,id_cach-128
	ld	bc,128
	inc	a
id_rdw1:add	hl,bc
	dec	a
	jr	nz,id_rdw1
	ret

; Reads a sector and DMA transfers it to memory
id_read:call	id_rdwr
	or	a
	ret	nz
	ldir
	ret


; Write a sector from DMA, and defer it if possible
id_writ:push	bc
	call	id_rdwr
	or	a
	pop	bc
	ret	nz
	ld	a,1
	ld	(id_dirt),a
	ld	a,c
	ld	bc,128
	ex	de,hl
	ldir
	cp	1
	ld	a,0
	ret	nz
	
	; Drop down to defer read


; Checks to see if the cache needs to be written back
; after a deferred write.
;
; uses, af
id_wdef:ld	a,(id_dirt)
	or	a
	jr	z,id_wde4

	push	bc
	push	de
	push	hl
	
	
	; Write physical sector
	call	id_dint
	call	id_dvsc
	ld	a,(id_io)
	ld	c,a
	add	a,3
	ld	d,a
	ld	e,c
	ld	a,0xA8		; Write command
	out	(c),a
	ld	hl,id_cach
id_wde1:in	a,(c)
	rra	
	jr	nc,id_wde2
	rra
	jr	nc,id_wde1
	ld	c,d
	outi 
	ld	c,e
	jr	id_wde1
id_wde2:call	id_eint
	in	a,(c)
	
	; Deselect drive
	ld	b,a
	call	id_udsl
	ld	a,b
	
	pop	hl
	pop	de
	pop	bc
	
	; Error checking
	and	0xFC
	jr	z,id_wde3
	
	ld	a,1
	ret
	
	; Cache is no longer dirty
id_wde3:ld	(id_dirt),a
	
	; Data no longer in core
id_wde4:xor	a
	ld	(id_inco),a
	
	ret
	
; Loads the GRB into memory from sector 2-3
id_grb:	ld	a,2
	ld	(id_r2ks),a
	jr	id_r2k
	
; Loads the CCP into memory from sectors 4-5
id_ccp:	ld	a,4
	ld	(id_r2ks),a

; Reads in a 2K bytes, starting at track 0, sector (id_r2ks)
; This is placed into the cbase
id_r2k: ld	a,id_rdsk
	call	id_dvsl
	
	; Restore to track 0
	ld	a,(id_io)
	ld	c,a
	ld	a,0x09
	out	(c),a 
	call	id_busy
	
	; Set sector # to 4
	ld	a,(id_r2ks)
	inc	c
	inc	c
	out	(c),a
	push	bc
	dec	c
	dec	c
	
	; Read into memory
	ld	hl,cbase
	call	id_rphy
	pop	bc
	or	a
	jr	z,id_r2k0
	call	id_init		; Error!
	jr	id_r2k
	
	; Increment sector
id_r2k0:in	a,(c)
	inc	a
	out	(c),a
	dec	c
	dec	c
	
	; Read into memory again
	call	id_rphy
	or	a
	ret	z
	call	id_init		; Error!
	jr	id_r2k
	
	; De-select drive
	jp	id_udsl

; Reads a physical sector
; Track and sector should be set up
; c = FDC command address
; hl = memory location of result
;
; Returns a=0 if successful
; uses: af, bc, de, hl
id_rphy:call	id_dint
	ld	d,c
	ld	e,c
	inc	d
	inc	d
	inc	d
	
	; Read command
	ld	a,0x88
	out	(c),a
id_rph1:in	a,(c)
	rra	
	jr	nc,id_rph2
	rra
	jr	nc,id_rph1
	ld	c,d
	ini
	ld	c,e
	jr	id_rph1
id_rph2:call	id_eint
	in	a,(c)
	and	0xFC
	ret

; Selects or deselects a drive
; a = Drive density / selection
;
; uses: af
id_dvsc:ld	a,(id_curd)	; Select current drive
	jr	id_dvsl
id_udsl:xor	a		; Unselects a drive
id_dvsl:push	bc
	ld	b,a
	ld	a,(id_io)
	add	a,0x0F
	ld	c,a
	out	(c),b
	ld	b,0xFF
	call	id_stal
	pop	bc
	ret
	

; Waits until FDC is not busy
; c = FDC command address
;
; uses: af
id_busy:in	a,(c)
	rra
	jr	c,id_busy
	ret
	
; Waits a little bit
;
; uses: b
id_stal:push	bc
	pop	bc
	djnz	id_stal
	ret