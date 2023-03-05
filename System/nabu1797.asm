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

; Disk A DPH
nf_dpha:
	defw	0,0,0,0
	defw	dircbuf
	defw	nf_dpb
	defw	0
	defw	nf_asva

; Disk B DPH
nf_dphb:
	defw	0,0,0,0
	defw	dircbuf
	defw	nf_dpb
	defw	0
	defw	nf_asvb

; Osborne 1 format
nf_dpb:
	defw	20	; # sectors per track
	defb	3	; BSH
	defb	7	; BLM
	defb	0	; EXM
	defw	189	; DSM
	defw	63	; DRM
	defb	0xC0	; AL0
	defb	0	; AL1
	defw	0	; Size of directory check vector
	defw	3	; Number of reserved tracks at the beginning of disk


; Driver entry point
; a = Command #
;
; uses: all
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
	ld	(nf_curd),a
	
	; Force FDC interrupt
	ld	a,0xD0
	out	(c),a
	
	; Re-home drive
	call	nf_home
	
	; De-select drive
	
	ret

; Sends the drive to track 0, and syncs the drive
;
; uses : af, c
nf_home:call	nf_wdef
	call	nf_dvsc

	ld	a,(nf_io)
	ld	c,a
	
	; Restore to track 0
	ld	a,0x09
	out	(c),a 
	call	nf_busy
	
	; Reset sync flag
	xor	a
	ld	(nf_sync),a
	
	; De-select drive
	jp	nf_udsl
	
; Selects the drive
; c = Logging status
; hl = Call argument
;
; uses; all
nf_sel:	ld	a,l
	ld	b,2
	or	a
	jr	z,nf_sel0
	dec	a
	ld	b,4
	jr	z,nf_sel0
	ld	hl,0
	ret
nf_sel0:ld	a,(nf_curd)	
	cp	b		; Compare to current drive
	ret	z

	call	nf_wdef		; Write back if needed
	ld	a,0xFF
	ld	(nf_sync),a	; Set sync flag
	ld	a,b
	ld	(nf_curd),a	; Set current drive
	
	; TODO DPH
	ld	hl,nf_dpha
	ld	a,2
	cp	b
	ret	z
	
	ld	hl,nf_dphb
	
	ret
; Sets the track of the selected block device
; bc = Track, starts at 0
; hl = Call argument
;
; uses: all
nf_strk:ld	d,c		; Track = d
	ld	a,(nf_io)
	ld	c,a
	ld	a,(nf_sync)
	or	a
	jr	z,nf_str0	; Check if disk direct
	
	call	nf_dvsc
	
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

	; Write a deferred block
	call	nf_wdef

	; Seek to track
	call	nf_dvsc
	inc	c
	inc	c
	out	(c),d
	ld	a,0x19
	ld	c,e
	out	(c),a 
	call	nf_busy	
	
	jp	nf_udsl

; Sets the sector of the selected block device
; bc = Sector, starts at 0
; hl = Call argument
;
; uses: all
nf_ssec:ld	a,c
	and	0x07
	ld	(nf_subs),a
	ld	a,c
	
	; Compute physical sector
	srl	a
	srl	a
	srl	a
	inc	a
	ld	b,a	; b = Physical sector
	ld	a,(nf_io)
	inc	a
	inc	a
	ld	c,a
	in	a,(c)
	cp	b
	ret	z	; Return if the same
	
	; Set FDC sector, after writing back if needed
	call	nf_wdef
	out	(c),b
	ret
	
	
; Read a sector and DMA
;
; uses: all
nf_read:ld	a,(nf_inco)
	or	a
	jr	nz,nf_rea0
	
	; Read in to cache
	call	nf_dvsc
	ld	a,(nf_io)
	ld	c,a
	ld	hl,nf_cach
	call	nf_rphy
	ld	b,a
	call	nf_udsl
	ld	a,b
	
	; Error checking
	or	a
	ld	a,1
	ret	nz
	ld	(nf_inco),a
	
	; DMA subsector
nf_rea0:ld	hl,(biodma)
	ex	de,hl

	ld	a,(nf_subs)
	ld	hl,nf_cach-128
	ld	bc,128
	inc	a
nf_rea1:add	hl,bc
	dec	a
	jr	nz,nf_rea1
nf_rea2:ldir
	ret


nf_writ:ld	a,1
	ret


; Checks to see if the cache needs to be written back
; after a deferred write.
;
; uses, af
nf_wdef	xor	a
	ld	(nf_inco),a
	
	; Check if cache is dirty
	ld	a,(nf_dirt)
	or	a
	ret	z

	push	bc
	push	de
	push	hl
	; TODO: Do write here
	push	hl
	pop	de
	pop	bc
	
	; Cache is no longer dirty
	ld	(nf_dirt),a
	
	
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


; Variables
nf_io:	equ	nf_bss	; FDC address
nf_r2ks:equ	nf_bss+1; Temp storaged used in nf_r2k

nf_curd:equ	nf_bss+2; Currently selected disk
nf_subs:equ	nf_bss+3; Current subsector
nf_sync:equ	nf_bss+4; Set if disk needs to be rehomed
nf_inco:equ	nf_bss+5; Set if sector is in core already
nf_dirt:equ	nf_bss+6; Set if cache is dirty

; Misc CP/M buffer
nf_asva:equ	nf_bss+7
nf_asvb:equ	nf_bss+32