;
;**************************************************************
;*
;*            N A B U   H C C A   C O M M O N
;*
;*      This device is not a standalone driver, but
;*      instead contains common HCCA interface code
;*      used between the NDSK, NFS, and other HCCA
;*      devices.
;* 
;**************************************************************


; Set up the HCCA modem connection
; Configures the AY-3-8910 to monitor correct interrupts
; and leaves it in a state where the interrupt port is
; exposed
;
; uses: a, b
ns_hini:ld	a,0x07
	out	(ns_atla),a	; AY register = 7
	in	a,(ns_ayda)
	and	0x3F
	or	0x40
	out	(ns_ayda),a	; Configure AY port I/O
	
	; Claim interrupt vectors
	push	hl
	ld	hl,ns_rirq
	ld	(intvec),hl
	ld	hl,ns_wirq
	ld	(intvec+2),hl
	pop	hl
	
; Set interrupts to their default state
;
; uses: a
ns_dflt:ld	a,0x0E
	out	(ns_atla),a	; AY register = 14
	ld	a,0xB0
	out	(ns_ayda),a	; Enable HCCA receive and but not send, plus key and VDP
	
ns_dfl0:ld	a,0x0F		
	out	(ns_atla),a	; AY register = 15
	
	ret

; Set receive and send interrupts
;
; uses: a
ns_esnd:ld	a,0x0E
	out	(ns_atla),a	; AY register = 14
	ld	a,0xC0
	out	(ns_ayda),a	; Enable HCCA receive and send
	jr	ns_dfl0
	
; Set receive but not send interrupt
;
; uses: a
ns_dsnd:ld	a,0x0E
	out	(ns_atla),a	; AY register = 14
	ld	a,0x80
	out	(ns_ayda),a	; Enable HCCA receive and but not send
	jr	ns_dfl0

; Gets a block from the currently open file
; and places it in (hl)
; de = Block to read
; hl = Destination for information
;
; Returns location directly after in hl
; Carry flag set on error
; uses: af, b, hl
ns_getb:call	ns_get0
	jp	ns_dflt
ns_get0:ex	de,hl
	ld	(ns_m2bn),hl
	ex	de,hl
	push	hl
	ld	hl,ns_m2
	ld	b,12
	call	ns_send
	pop	hl
	ret	c
	call	ns_hcrd
	call	ns_hcre
	ret	c
	cp	0x84
	scf
	jr	nz,ns_get2
	call	ns_hcre
	ld	(ns_tran),a
	ld	b,a
	call	ns_hcre
	ld	a,b
	or	a
	ret	z
ns_get1:call	ns_hcre
	ret	c
	ld	(hl),a
	inc	hl
	djnz	ns_get1
	or	a
	ret
ns_get2:call	ns_hcrd	; Read the error message and exit
	call	ns_hcre
	scf
	ret
	
; Puts a block into the currently open file
; from that location (hl)
; de = Block to write
; hl = Source of information
;
; Carry flag set on error
; uses: af, b, hl
ns_putb:call	ns_put0
	jp	ns_dflt
ns_put0:ex	de,hl
	ld	(ns_m3bn),hl
	ex	de,hl
	push	hl
	ld	hl,ns_m3
	ld	b,12
	call	ns_send		; Send message precursor
	pop	hl
	ret	c
	ld	b,128
ns_put1:ld	a,(hl)		; Send the block
	call	ns_hcwr
	ret	c
	inc	hl
	djnz	ns_put1
	ld	hl,ns_buff
	call	ns_rece
	ld	a,(ns_buff)
	cp	0x81
	ret	z
	scf
	ret
	
; Receives a general response from the NHACP server
; hl = Destination of message
;
; Carry flag set on error
; uses: af, b, hl
ns_rece:call	ns_dsnd
	call	ns_rec0
	jp	ns_dflt
ns_rec0:call	ns_hcre
	ret	c		; Existing error
	ld	b,a
	call	ns_hcre
	ret	c		; Existing error
	scf
	ret	nz		; Message too big!
ns_rec1:call	ns_hcre
	ret	c		; Error!
	ld	(hl),a
	inc	hl
	djnz	ns_rec1
	or	a
	ret
	
; Write a number of bytes to the HCCA port
; b = Bytes to write
; hl = Start of message
;
; Carry flag set on error
; uses: af, b, hl
ns_send:ld	a,(hl)
	inc	hl
	call	ns_hcwr
	ret	c		; Error!
	djnz	ns_send
	ret
	
; Read from the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
;
; Returns result in a
; Carry flag set on error
; Uses: af
ns_hcrd:call	ns_hcre
ns_hcre:xor	a
	ld	(ns_inf),a
	push	de
	ld	a,0x09
	out	(ns_nctl),a	; Turn on recv light
	ld	de,0xFFFF
ns_hcr0:ld	a,(ns_inf)
	or	a
	jr	nz,ns_hcr2
	in	a,(ns_ayda)
	;bit	0,a
	;jr	z,ns_hcr0	; Await an interrupt
	;bit	1,a
	;jr	z,ns_hcr1
	and	0x0F
	xor	0b00000001
	jr	z,ns_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcr0
ns_hcer:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	scf
	pop	de
	ret			; Timed out waiting
ns_hcr1:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	in	a,(ns_hcca)
	pop	de
	or	a
	ret
ns_hcr2:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	xor	a
	ld	(ns_inf),a
	ld	a,(ns_inb)
	pop	de
	ret
	
; HCCA read interrupt
; Reads from the HCCA, buffers it, and then sets the flag
;
; uses: none
ns_rirq:push	af
	in	a,(ns_hcca)
	ld	(ns_inb),a
	ld	a,1
	ld	(ns_inf),a
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
ns_hcwr:push	de
	ld	(ns_outb),a
	xor	a
	ld	(ns_outf),a
	call	ns_esnd
	ld	de,0xFFFF
	ld	a,0x21
	out	(ns_nctl),a	; Turn on send light
ns_hcw0:ld	a,(ns_outf)
	or	a
	jr	nz,ns_hcw2
	in	a,(ns_ayda)
	;bit	0,a
	;jr	z,ns_hcw0	; Await an interrupt
	;bit	1,a
	;jr	nz,ns_hcw1
	and	0x0F
	xor	0b00000011
	jr	z,ns_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcw0
	call	ns_dsnd
	jr	ns_hcer		; Timed out waiting
ns_hcw1:ld	a,(ns_outb)
	out	(ns_hcca),a
ns_hcw2:pop	de
	ld	a,0x01
	out	(ns_nctl),a	; Turn off send light
	call	ns_dsnd
	or	a
	ret
	
; HCCA write interrupt
; Writes to the HCCA from the buffer, and 
ns_wirq:push	af
	ld	a,(ns_outb)
	out	(ns_hcca),a
	ld	a,1
	ld	(ns_outf),a
	call	ns_dsnd		; Y'all can't behave, turning off
	pop	af
	ei
	ret