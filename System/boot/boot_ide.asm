;
;**************************************************************
;*
;*        I S H K U R   I D E   B O O T S T R A P
;*
;**************************************************************
;

id_base	equ	0xC0

aydata	equ	0x40		; AY-3-8910 data port
aylatc	equ	0x41		; AY-3-8910 latch port
hcca	equ	0x80		; Modem data port
tmdata	equ	0xA0		; TMS9918 data port
tmlatc	equ	0xA1		; TMS9918 latch port

buffer	equ	0x8000		; General purpose memory buffer

	; NABU bootstrap loads in at 0xC000
	org	0xC000
	
; First 8 bytes should not be changed
; The JR instruction doubles as a magic number
; The other 6 bytes can be used as parameters during system generation
base:	jr	start
ldaddr:	defw	0
nsec:	defb	0
	defb	0
	defw	0
start:	jr	tmsini

; Panic!
; Just jump to the start of ROM at this point
panic:	jp	0
	
	; Change TMS color mode to indicate successful boot
tmsini:	in	a,(0xA1)
	ld	a,0xE1
	out	(0xA1),a
	ld	a,0x87
	out	(0xA1),a

	; The system may still expect NHACP to be set up

	; Set up the HCCA modem connection
	ld	a,0x07
	out	(aylatc),a	; AY register = 7
	ld	a,0x7F
	out	(aydata),a	; Configure AY port I/O
	
	ld	a,0x0E
	out	(aylatc),a	; AY register = 14
	ld	a,0xC0
	out	(aydata),a	; Enable HCCA receive and send
	
	ld	a,0x0F
	out	(aylatc),a	; AY register = 15
	
	; Send "HELLO" to NHACP server
	ld	hl,m_start
	ld	b,8
	call	modsend
	
	; Get confirmation
	call	modrecb
	ld	a,(buffer)
	
	; We don't really care if it worked or not, lets load the CP/M image off of the IDE drive
	
ideboot:ld	a,0xE0
	out	(id_base+0xC),a
	ld	b,10
	call	id_stal
	in	a,(id_base+0xC)
	inc	a
	jp	z,panic		; Can't select disk, panic!

	; Load nsec number of sectors into ldaddr
	ld	hl,(ldaddr)
	ld	a,(nsec)
	ld	b,a
	ld	c,9
	xor	a
	out	(id_base+0x8),a
	out	(id_base+0xA),a
	
id_load:ld	a,c
	out	(id_base+0x6),a
	push	bc
	call	id_rphy
	pop	bc
	jp	nz,panic
	inc	c
	djnz	id_load
	
	; Jump to system
	ld	hl,(ldaddr)
	ld	de,0xE00
	add	hl,de
	jp	(hl)
	
	
; Sends a message to the HCCA modem
; b = # of bytes to send
; hl = pointer to address
;
; uses: af, b, hl
modsend:ld	a,0x8F		; Send NHACP message
	call	hccawri
	xor	a		; Send session
	call	hccawri
	ld	a,b
	call	hccawri		; Send size of packet
	xor	a
	call	hccawri
modsen0:ld	a,(hl)
	call	hccawri
	inc	hl
	djnz	modsen0
	ret
	
; Receives a message back from the HCCA
; hl = pointer to address
;
; uses: af, b, hl
modrecb:ld	hl,buffer	; Read directly into buffer
modrece:call	hccarea
	ld	b,a
	call	hccarea
modrec0:call	hccarea
	ld	(hl),a
	inc	hl
	djnz	modrec0
	ret


; Read from the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
;
; Returns return in a
; Uses: af
hccared:call	hccarea		; Reads 2 bytes, discards 1
hccarea:push	de
	ld	de,0x2FFF
hccare0:dec	de
	ld	a,e
	or	d
	jp	z,ideboot	; Timed out waiting, do an ide boot instead
	in	a,(aydata)
	bit	0,a
	jr	z,hccare0	; Await an interrupt
	bit	1,a
	jr	nz,hccare0
hccare1:in	a,(hcca)
	pop	de
	ret
	
; Write to the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
; a = Character to write
;
; Uses: none
hccawri:push	de
	push	af
	ld	de,0xFFFF
hccawr0:in	a,(aydata)
	bit	0,a
	jr	z,hccawr0	; Await an interrupt
	bit	1,a
	jr	nz,hccawr1
	dec	de
	ld	a,e
	or	d
	jr	nz,hccawr0
	jp	panic		; Timed out waiting
hccawr1:pop	af
	out	(hcca),a
	pop	de
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
	
; NHACP start message
; Disables CRC mode
m_start:defb	0x00,'ACP',0x01,0x00,0x00,0x00
