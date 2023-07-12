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
hc_hini:ld	a,0x07
	out	(hc_atla),a	; AY register = 7
	in	a,(hc_ayda)
	and	0x3F
	or	0x40
	out	(hc_ayda),a	; Configure AY port I/O
	
	; Claim interrupt vectors
	push	hl
	ld	hl,hc_rirq
	ld	(intvec),hl
	ld	hl,hc_wirq
	ld	(intvec+2),hl
	pop	hl
	
	; Record default interrupt modes
	ld	a,0x0E
	out	(hc_atla),a	; AY register = 14
	in	a,(hc_atla)
	ld	(hc_intm),a
	
; Set interrupts to their default state
;
; uses: a
hc_dflt:ld	a,0x0E
	out	(hc_atla),a	; AY register = 14
	ld	a,0xB0
	out	(hc_ayda),a	; Enable HCCA receive and but not send, plus key and VDP
	
hc_dfl0:ld	a,0x0F		
	out	(hc_atla),a	; AY register = 15
	
	ret

; Set receive and send interrupts
;
; uses: a
hc_esnd:ld	a,0x0E
	out	(hc_atla),a	; AY register = 14
	ld	a,0xC0
	out	(hc_ayda),a	; Enable HCCA receive and send
	jr	hc_dfl0
	
; Set receive but not send interrupt
;
; uses: a
hc_dsnd:ld	a,0x0E
	out	(hc_atla),a	; AY register = 14
	ld	a,0x80
	out	(hc_ayda),a	; Enable HCCA receive and but not send
	jr	hc_dfl0

; Gets a block from the currently open file
; and places it in (hl)
; a = Target file descriptor
; de = Block to read
; hl = Destination for information
;
; Returns location directly after in hl
; Carry flag set on error
; uses: af, b, hl
hc_getb:ld	(hc_m2fd),a
	call	hc_get0
	jp	hc_dflt
hc_get0:ex	de,hl
	ld	(hc_m2bn),hl
	ex	de,hl
	push	hl
	ld	hl,hc_m2
	ld	b,12
	call	hc_send
	pop	hl
	ret	c
	call	hc_hcrd
	call	hc_hcre
	ret	c
	cp	0x84
	scf
	jr	nz,hc_get2
	call	hc_hcre
	ld	(hc_tran),a
	ld	b,a
	call	hc_hcre
	ld	a,b
	or	a
	ret	z
hc_get1:call	hc_hcre
	ret	c
	ld	(hl),a
	inc	hl
	djnz	hc_get1
	or	a
	ret
hc_get2:call	hc_hcrd	; Read the error message and exit
	call	hc_hcre
	scf
	ret
	
; Puts a block into the currently open file
; from that location (hl)
; de = Block to write
; hl = Source of information
;
; Carry flag set on error
; uses: af, b, hl
hc_putb:ld	(hc_m3fd),a
	call	hc_put0
	jp	hc_dflt
hc_put0:ex	de,hl
	ld	(hc_m3bn),hl
	ex	de,hl
	push	hl
	ld	hl,hc_m3
	ld	b,12
	call	hc_send		; Send message precursor
	pop	hl
	ret	c
	ld	b,128
hc_put1:ld	a,(hl)		; Send the block
	call	hc_hcwr
	ret	c
	inc	hl
	djnz	hc_put1
	ld	hl,hc_buff
	call	hc_rece
	ld	a,(hc_buff)
	cp	0x81
	ret	z
	scf
	ret
	
; Receives a general response from the NHACP server
; hl = Destination of message
;
; Carry flag set on error
; uses: af, b, hl
hc_rece:call	hc_dsnd
	call	hc_rec0
	jp	hc_dflt
hc_rec0:call	hc_hcre
	ret	c		; Existing error
	ld	b,a
	call	hc_hcre
	ret	c		; Existing error
	scf
	ret	nz		; Message too big!
hc_rec1:call	hc_hcre
	ret	c		; Error!
	ld	(hl),a
	inc	hl
	djnz	hc_rec1
	or	a
	ret
	
; Write a number of bytes to the HCCA port
; b = Bytes to write
; hl = Start of message
;
; Carry flag set on error
; uses: af, b, hl
hc_send:ld	a,(hl)
	inc	hl
	call	hc_hcwr
	ret	c		; Error!
	djnz	hc_send
	ret
	
; Read from the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
;
; Returns result in a
; Carry flag set on error
; Uses: af
hc_hcrd:call	hc_hcre
hc_hcre:xor	a
	ld	(hc_inf),a
	push	de
	ld	a,0x09
	out	(hc_nctl),a	; Turn on recv light
	ld	de,0xFFFF
hc_hcr0:ld	a,(hc_inf)
	or	a
	jr	nz,hc_hcr2
	in	a,(hc_ayda)
	;bit	0,a
	;jr	z,hc_hcr0	; Await an interrupt
	;bit	1,a
	;jr	z,hc_hcr1
	and	0x0F
	xor	0b00000001
	jr	z,hc_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,hc_hcr0
hc_hcer:ld	a,0x01
	out	(hc_nctl),a	; Turn off recv light
	scf
	pop	de
	ret			; Timed out waiting
hc_hcr1:ld	a,0x01
	out	(hc_nctl),a	; Turn off recv light
	in	a,(hc_hcca)
	pop	de
	or	a
	ret
hc_hcr2:ld	a,0x01
	out	(hc_nctl),a	; Turn off recv light
	xor	a
	ld	(hc_inf),a
	ld	a,(hc_inb)
	pop	de
	ret
	
; HCCA read interrupt
; Reads from the HCCA, buffers it, and then sets the flag
;
; uses: none
hc_rirq:push	af
	in	a,(hc_hcca)
	ld	(hc_inb),a
	ld	a,1
	ld	(hc_inf),a
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
hc_hcwr:push	de
	ld	(hc_outb),a
	xor	a
	ld	(hc_outf),a
	call	hc_esnd
	ld	de,0xFFFF
	ld	a,0x21
	out	(hc_nctl),a	; Turn on send light
hc_hcw0:ld	a,(hc_outf)
	or	a
	jr	nz,hc_hcw2
	in	a,(hc_ayda)
	;bit	0,a
	;jr	z,hc_hcw0	; Await an interrupt
	;bit	1,a
	;jr	nz,hc_hcw1
	and	0x0F
	xor	0b00000011
	jr	z,hc_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,hc_hcw0
	call	hc_dsnd
	jr	hc_hcer		; Timed out waiting
hc_hcw1:ld	a,(hc_outb)
	out	(hc_hcca),a
hc_hcw2:pop	de
	ld	a,0x01
	out	(hc_nctl),a	; Turn off send light
	call	hc_dsnd
	or	a
	ret
	
; HCCA write interrupt
; Writes to the HCCA from the buffer, and 
hc_wirq:push	af
	ld	a,(hc_outb)
	out	(hc_hcca),a
	ld	a,1
	ld	(hc_outf),a
	call	hc_dsnd		; Y'all can't behave, turning off
	pop	af
	ei
	ret
	
; Interrupt modes
hc_intm:
	defb	0
	
; Message prototype to read a block
; Total length: 12 bytes
hc_m2:	defb	0x8F,0x00
	defw	8		; Message length
	defb	0x07		; Cmd: STORAGE-GET-BLOCK
hc_m2fd:defb	hc_fild		; Default file descritor
hc_m2bn:defw	0x00,0x00	; Block number
	defw	128		; Block length
	
; Message prototype to write a block
; Total length: 12 bytes
hc_m3:	defb	0x8F,0x00
	defw	136		; Message length
	defb	0x08		; Cmd: STORAGE-PUT-BLOCK
hc_m3fd:defb	hc_fild		; Default file descritor
hc_m3bn:defw	0x00,0x00	; Block number
	defw	128		; Block length