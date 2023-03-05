;
;**************************************************************
;*
;*      N A B U   F D 1 7 9 7   F L O P P Y   D R I V E R
;*
;*      This driver interfaces the NABU FDC for use as a
;*      CP/M file system, graphical source, and boot device.
;*      The driver only supports double-density disks of 
;*      Osborne 1 format at the time, but this could be
;*      updated if it is needed. The directory table starts
;*      on track 2, the system sectors are as follows:
;*
;*      Track 0 Sector 1:	Boot Sector
;*      Track 0 Sector 2-3:	Graphical Resource Block
;*	Track 0 Sector 4-5:	CCP
;*	Track 1 Sector 1-5:	BDOS + BIOS Image
;* 
;**************************************************************
;

nf_rdsk	equ	2	; Defines which drives contains system
			; resources (2 = A, 4 = B)

;
;**************************************************************
;*
;*         D I S K   D R I V E   G E O M E T R Y
;* 
;**************************************************************
;

nfddev:	or	a
	jr	z,nf_init
	dec	a
	jr	z,nf_home
	dec	a
	jr	z,nf_sel
	dec	a
	jp	z,nf_strk
	dec	a
	jp	z,nf_ssec
	dec	a
	jp	z,nf_read
	jp	nf_writ
	
; Initialize device
; Sets the current track to 0
nf_home:
nf_init:xor	a
	ld	(nf_io),a

	; Look for the FDC
	ld	c,0xCF
nf_ini1:in	a,(c)
	cp	0x10
	jr	z,nf_ini2
	inc	c
	ret	z	; Should not be possible!
	ld	a,0x0F
	add	a,c
	ld	c,a
	jr	nf_ini1
	
	; Get command register
nf_ini2:ld	a,c
	sub	15
	ld	c,a
	ld	(nf_io),a
	
	; Select drive defined by hl
	sla	l
	ld	a,2
	add	l
	call	nf_dvsl
	
	; Force FDC interrupt
	ld	a,0xD0
	out	(c),a
	
	; Restore to track 0
	ld	a,0x09
	out	(c),a 
	call	nf_busy
	
	; De-select drive
	call	nf_udsl
	ret
	
; Selects the drive
; c = Logging status
; hl = Call argument
;
; uses; all
nf_sel:	xor	a
	ld	b,2
	cp 	l
	jr	z,nf_sel0
	inc	a
	cp	l
	ld	b,4
	jr	z,nf_sel0
	ld	hl,0
	ret
nf_sel0:ld	a,(nf_curd)	
	cp	b		; Compare to current drive
	ret	z

	call	nf_free
	ld	a,0xFF
	ld	(nf_sync),a	; Set sync flag
	ld	a,b
	ld	(nf_curd),a	; Set current drive
	inc	hl
	ret

; Free the cache, if needed
;
; uses: af
nf_free:ld	a,(nf_ocac)
	or	a
	ret	z
	push	bc
	push	de
	ld	hl,nulldev
	call	chclaim
	pop	de
	pop	bc
	ret

; Sets the track of the selected block device
; bc = Track, starts at 0
; hl = Call argument
;
; uses: all
nf_strk:call	nf_dvsc
	ld	d,c		; Track = d
	ld	a,(nf_io)
	ld	c,a
	ld	a,(nf_sync)
	or	a
	jr	z,nf_str0	; Check if disk direct
	
	; Restore to track 0
	ld	a,0x09
	out	(c),a 
	call	nf_busy
	
	; Reset sync flag
	xor	a
	ld	(nf_sync),a
	
	; Check to see if tracks match
nf_str0:ld	e,c
	inc	c
	in	a,(c)
	cp	d
	jp	z,nf_udsl	; They match, do nothing

	; Free the cache
	call	nf_free
	
	; Seek to track
	inc	c
	inc	c
	out	(c),d
	ld	a,0x19
	ld	c,e
	out	(c),a 
	call	nf_busy	
	
	jp	nf_udsl

; Sets the sector of the selected block device
; bc = Sector, starts at 1
; hl = Call argument
;
; uses: all
nf_ssec:dec	c
	ld	a,c
	and	0x07
	ld	(nf_subs),a
	
	; Compute physical sector
	rra
	rra
	rra
	inc	a
	ld	b,a	; b = Physical sector
	ld	a,(nf_io)
	inc	a
	inc	a
	ld	c,a
	in	a,(c)
	cp	b
	ret	z	; Return if the same
	
	; Set FDC sector, after freeing cache
	call	nf_free
	out	(c),b
	ret
	
	
; Read a sector and DMA
;
; uses: all
nf_read:ld	a,(nf_ocac)
	or	a
	jr	nz,nf_rea0
	
	; Read in to cache
	ld	hl,nf_wdef
	call	chclaim
	ld	a,(nf_io)
	ld	c,a
	ld	hl,cache
	call	nf_rphy
	
	; Error checking
	or	a
	ld	a,1
	ret	nz
	ld	(nf_ocac),a
	
	; DMA subsector
nf_rea0:ld	hl,(biodma)
	ex	de,hl

	ld	a,(nf_subs)
	ld	hl,cache-128
	ld	bc,128
	inc	a
nf_rea1:add	hl,bc
	dec	a
	jr	nz,nf_rea1
nf_rea2:otir
	ret


nf_writ:ld	a,1
	ret


; Handles the releasing of the cache 
nf_wdef:xor	a
	ld	(nf_ocac),a

	; Check if cache is dirty
	ld	a,(nf_dirt)
	or	a
	ret	z

	; TODO: Do write here
	
	ret
	
; Loads the GRB into memory from sector 2-3
nf_grb:	ld	a,2
	ld	(nf_r2ks),a
	jr	nf_r2k
	
; Loads the CCP into memory from sectors 4-5
nf_ccp:	ld	a,4
	ld	(nf_r2ks),a

; Reads in a 2K bytes, starting at track 0, sector (nf_r2ks)
; This is placed into the cbase
nf_r2k: ld	a,nf_rdsk
	call	nf_dvsl
	
	; Restore to track 0
	ld	a,(nf_io)
	ld	c,a
	ld	a,0x09
	out	(c),a 
	call	nf_busy
	
	; Set sector # to 4
	ld	a,(nf_r2ks)
	inc	c
	inc	c
	out	(c),a
	push	bc
	dec	c
	dec	c
	
	; Read into memory
	ld	hl,cbase
	call	nf_rphy
	pop	bc
	or	a
	jr	z,nf_r2k0
	call	nf_init		; Error!
	jr	nf_r2k
	
	; Increment sector
nf_r2k0:in	a,(c)
	inc	a
	out	(c),a
	dec	c
	dec	c
	
	; Read into memory again
	call	nf_rphy
	or	a
	ret	z
	call	nf_init		; Error!
	jr	nf_r2k
	
	; De-select drive
	jp	nf_udsl

; Reads a physical sector
; Track and sector should be set up
; c = FDC command address
; hl = memory location of result
;
; Returns a=0 if successful
; uses: af, bc, de, hl
nf_rphy:ld	d,c
	ld	e,c
	inc	d
	inc	d
	inc	d
	
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
	ld	a,b
	out	(c),a
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


; Variables
nf_io:	defb	0	; FDC address
nf_r2ks:defb	0	; Temp storaged used in nf_r2k

nf_curd:defb	0	; Currently selected disk
nf_subs:defb	0	; Current subsector
nf_sync:defb	0	; Set if disk needs to be rehomed
nf_ocac:defb	0	; Set if the driver owner the cache
nf_dirt:defb	0	; Set if cache is dirty