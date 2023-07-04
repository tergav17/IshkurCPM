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
id_dphc:
	defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	id_dpb	; DPB
	defw	0	; CSV
	defw	id_alvc	; ALV
	
; Disk D DPH
id_dphd:
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
	defw	1020	; DSM
	defw	1023	; DRM
	defb	0xF0	; AL0
	defb	0	; AL1
	defw	0	; Size of directory check vector
	defw	3	; Number of reserved tracks at the beginning of disk


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
	ld	a,c
	ld	(id_csec),a
	ret	z	; No effective change!
	call	id_wdef
	;	Fall to id_gbno
	
; Sets the IDE registers to point at the current geometric block
;
; Returns block # in de
; uses: af, de, hl 
id_sbno:ld	hl,(id_ctrk)
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	a,(id_csec)
	srl	a
	srl	a
	or	l
	out	(id_base+0x6),a
	ld	a,(id_curd)
	or	h
	out	(id_base+0x8),a
	xor	a
	out	(id_base+0xA),a
	ret
	
; Ensure sector is in core, and set up for DMA transfer
;
; uses: all
id_rdwr:ld	a,(id_inco)
	or	a
	jr	nz,id_rdw0
	
	; Read in to cache
	ld	hl,id_cach
	call	id_rphy
	
	; Error checking
	ld	a,1
	ret	nz
	ld	(id_inco),a
	
	; DMA subsector
id_rdw0:ld	hl,(biodma)
	ex	de,hl

	ld	a,(id_csec)
	and	0x03
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
	jr	z,id_wde1

	push	bc
	push	de
	push	hl
	
	; Write physical sector
	ld	hl,id_cach
	call	id_wphy
	
	pop	hl
	pop	de
	pop	bc
	
	; Error checking
	jr	z,id_wde0
	
	ld	a,1
	ret
	
	; Cache is no longer dirty
id_wde0:xor	a
	ld	(id_dirt),a
	
	; Data no longer in core
id_wde1:xor	a
	ld	(id_inco),a
	
	ret
	
; Loads the GRB into memory from sector 2-3
id_grb:	ld	c,1
	jr	id_r2k
	
; Loads the CCP into memory from sectors 4-5
id_ccp:	ld	c,5

; Reads in a 2K bytes, starting at track 0, sector (id_r2ks)
; This is placed into the cbase
id_r2k: ld	a,(id_rdsk)
	out	(id_base+0xC),a
	ld	b,10
	call	id_stal

	; Prepare to load 4 sectors into cbase
	ld	hl,cbase
	ld	b,4
	xor	a
	out	(id_base+0x8),a
	out	(id_base+0xA),a
	
id_r2k0:ld	a,c
	out	(id_base+0x6),a
	push	bc
	call	id_rphy
	pop	bc
	inc	c
	djnz	id_r2k0
	ret


; Executes a read command
; hl = Destination of data
;
; Returns hl += 512
; uses: af, bc, d, hl
id_rphy:ld	a,1
	out	(id_base+0x04),a
	call	id_busy
	ld	a,0x20
	call	id_comm
	call	id_wdrq
	ld	d,0
	ld	c,id_base
id_rph0:ini
	inc	c
	ini
	dec	c
	dec	d
	jr	nz,id_rph0
	call	id_busy
	ret

; Executes a write command
; hl = Source of data
;
; Returns hl += 512
; uses: af, bc, hl
id_wphy:ld	a,1
	out	(id_base+0x04),a
	call	id_busy
	ld	a,0x30
	call	id_comm
	call	id_wdrq
	ld	b,0
id_wph0:ld	c,(hl)
	inc	hl
	ld	a,(hl)
	out	(id_base+1),a
	inc	hl
	ld	a,c
	out	(id_base),a
	djnz	id_wph0
	call	id_busy
	push	af
	ld	a,0xE7		; Flush cache, some drives expect this
	call	id_comm
	pop	af
	ret
	
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
;
; Resets flag z on error
id_busy:in	a,(id_base+0xE)
	bit	6,a
	jr	z,id_busy
	bit	7,a
	jr	nz,id_busy
	bit	0,a
	ret


; Waits a little bit
;
; uses: b
id_stal:push	bc
	pop	bc
	djnz	id_stal
	ret