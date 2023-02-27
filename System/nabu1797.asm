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
nfddev:	jp	nf_init	
	jp	nf_sel
	jp	nf_strk
	jp	nf_ssec
	jp	nf_sdma
	jp	nf_read
	jp	nf_writ
	
; Initialize device
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
	
	; Select the drive(s)
	ld	a,2
	call	nf_dvsl
	
	; Force FDC interrupt
	ld	a,0xD0
	out	(c),a
	
	; Restore to track 0
	ld	a,0x09
	out	(c),a 
	call	nf_busy
	
	; Disable device
	xor	a
	call	nf_dvsl
	ret
	
; Loads the GRB into memory from sector 2-3
nf_grb:	ld	a,2
	ld	(nf_2ksc),a
	jr	nf_r2k
	
; Loads the CCP into memory from sectors 4-5
nf_ccp:	ld	a,4
	ld	(nf_2ksc),a

; Reads in a 2K bytes, starting at track 0, sector (nf_2ksc)
; This is placed into the cbase
nf_r2k: ld	a,2
	call	nf_dvsl
	
	; Restore to track 0
	ld	a,(nf_io)
	ld	c,a
	ld	a,0x09
	out	(c),a 
	call	nf_busy
	
	; Set sector # to 4
	ld	a,(nf_2ksc)
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
	jr	z,nf_ccp1
	call	nf_init		; Error!
	jr	nf_r2k
	
	; Increment sector
nf_ccp1:in	a,(c)
	inc	a
	out	(c),a
	
	; Read into memory again
	ld	hl,cbase
	call	nf_rphy
	pop	bc
	or	a
	ret	z
	call	nf_init		; Error!
	jr	nf_r2k

nf_sel:	ret
nf_strk:ret
nf_ssec:ret
nf_sdma:ret
nf_read:ret
nf_writ:ret

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
nf_2ksc:defb	0	; Start of 2K block to load in