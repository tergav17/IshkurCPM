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
nf_init:ret

	; Look for the FDC
	ld	c,0xCF
nf_ini1:in	a,(c)
	cp	0x10
	jr	z,drsel
	inc	c
	jp	z,nf_init	; Should not be possible!
	ld	a,0x0F
	add	a,c
	ld	c,a
	jr	nf_ini1
	
	; Get command register
	ld	a,c
	sub	0x0F
	ld	c,a
	ld	(nf_io),a
	
	; Select the drive
	ld	a,2
	out	(c),a
	ld	b,0xFF
	call	nf_stal
	
	; Force FDC interrupt
	ld	a,0xD0
	out	(c),a
	
	; Restore to track 0
	ld	a,0x09
	out	(c),a
	call	fdbusy

nf_sel:	ret
nf_strk:ret
nf_ssec:ret
nf_sdma:ret
nf_read:ret
nf_writ:ret


; Waits until FDC is not busy
; c = FDC command address
;
; uses: a
nf_busy:in	a,(c)
	rra
	jr	c,nf_busy
	ret
	
; Waits a little bit
;
; uses: b
nf_stal:push	ix
	pop	ix
	djnz	nf_stal
	ret


; Variables
nf_io:	defb	0	; FDC address