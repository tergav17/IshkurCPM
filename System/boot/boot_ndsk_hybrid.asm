;
;*****************************************************************
;*
;*        I S H K U R   N D S K   H Y B R I D   B O O T S T R A P
;*
;*****************************************************************
;

nsec	equ	7		; # of BDOS+BIOS sectors 
				; (1024 bytes each)
mem	equ	54		; CP/M image starts at mem*1024
				; Should be same as cpm22.asm
				
aydata	equ	0x40		; AY-3-8910 data port
aylatc	equ	0x41		; AY-3-8910 latch port
hcca	equ	0x80		; Modem data port
tmdata	equ	0xA0		; TMS9918 data port
tmlatc	equ	0xA1		; TMS9918 latch port

buffer	equ	0x8000		; General purpose memory buffer

scratch	equ	0x3000
; NABU bootstrap loads in at 0xC000
entry	equ	0xC000 ; Bootloader entry address



	org	entry

	nop
	nop
	nop
start:
	ld sp, scratch + 3             ; Set stack pointer
	ld a, $C9                      ; A = $C9 (return opcode)
	ld (scratch), a                ; Place return statement at address 3000
	call scratch                   ; Call address 3000 (and return)
	ld hl, (scratch + 1)           ; Load return address from stack, this will be the address immediately following the call 3000 statement
	ld de, code_start-$ + 3        ; DE = address of bootloader relative to the call 0 return address
	add hl, de                     ; HL = absolute address where bootloader is currently residing
	ld de, entry                   ; DE = address to copy bootloader to.
	ld bc, code_length             ; BC = length of bootloader
	ldir                           ; Relocate ourselves to known address
	ld hl, entry                   ; HL = entry point of bootloader
	jp (hl)                        ; Jump to bootloader

.PHASE entry
code_start:  equ $$

; Boot start same as NABU bootstrap
base:
	di
	nop
	ld	sp,base
	jr	tmsini

; Panic!
; Just jump to the start of ROM at this point
panic:	jp	0
	
	; Change TMS color mode to indicate successful boot
tmsini:	in	a,(tmlatc)
	ld	a,0xE1
	out	(tmlatc),a
	ld	a,0x87
	out	(tmlatc),a
	
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
	
	cp	0x80		; Correct confirmation?
	jp	nz,panic
	

	; Open the file
	ld	hl,m_open
	ld	b,14
	call	modsend
	
	; Get file descriptor
	call	modrecb
	ld	a,(buffer)
	
	cp	0x83		; File opened?
	jp	nz,panic
	ld	a,(buffer+1)
	ld	(rfdesc),a
	ld	(cfdesc),a
	
	ld	hl,1024*(mem+2)	; Set base for loading data
readsec:ex	de,hl
	ld	hl,m_read
	ld	b,8
	call	modsend
	
	; Handle incoming data packet
	call	hccared
	call	hccarea
	cp	0x84
	jp	nz,panic
	call	hccared
	
	; Move it into memory
	ex	de,hl
	ld	de,0x400
readse0:call	hccarea
	ld	(hl),a
	inc	hl
	dec	de
	ld	a,d
	or	e
	jr	nz,readse0
	
	; See if we need to load another sector
	ld	a,(nsecle)
	dec	a
	jr	z,exec
	ld	(nsecle),a
	
	; Increment address
	ld	a,(rfaddr)
	inc	a
	ld	(rfaddr),a
	jr	readsec
	
	; Execute BDOS
exec:	ld	hl,m_close
	ld	b,2
	call	modsend
	
		
;loop:	jr	loop


	jp	0xE00+1024*(mem+2)
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
	ld	de,0xFFFF
hccare0:in	a,(aydata)
	bit	0,a
	jr	z,hccare0	; Await an interrupt
	bit	1,a
	jr	z,hccare1
	dec	de
	ld	a,e
	or	d
	jr	nz,hccare0
	jp	panic		; Timed out waiting
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
	
; NHACP start message
; Disables CRC mode
m_start:defb	0x00,'ACP',0x01,0x00,0x00,0x00

; NHACP open CP/M 2.2 image
m_open:	defb	0x01,0xFF,0x00,0x00,0x09,'CPM22.SYS'

; NHACP read block from open file
m_read:	defb	0x07
rfdesc:	defb	0x00		; Read command file descriptor
rfaddr:	defb	0x02		; Read command start offset
	defb	0x00,0x00,0x00
	defb	0x00,0x04
	
; NHACP close file
m_close:defb	0x05
cfdesc:	defb	0x00		; Close command file descriptor
	defw	0x00		; Fucking magic

; Variables
nsecle:	defb	nsec

code_length: equ $$-code_start
.DEPHASE
