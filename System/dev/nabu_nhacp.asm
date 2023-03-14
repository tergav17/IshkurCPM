;
;**************************************************************
;*
;*   N A B U   N H A C P   F I L E S Y S T E M   D R I V E R
;*
;*     This driver allows for IshkurCP/M to mount external
;*     directories as file systems using the NHACP protocol.
;*     Unlike standard CP/M drivers, this is done by 
;*     directly intercepting BDOS calls. As a result, most
;*     BIOS calls are ignored, and a dummy DPH is provided
;*     is is enough for CP/M to select the driver without
;*     issue. As a result, the following line must be added
;*     to the 'syshook:' function in config.asm:
;*
;*     `call	nh_sysh`
;*
;*     This particular driver uses the Nabu HCCA port to 
;*     facilitate communication between it and an adapter
;*
;*     Logical devices are defined by numbered directories
;*     in the root NHACP storage areas. For example, minor
;*     device 0 is stored in the '0' directory.
;*
;*     In order to service CCP and GRB requests, the 
;*     following special files must exist:
;*
;*     '0/CPM22.SYS' <- For CP/M system components
;*     '0/FONT.GRB' <- For graphical driver components
;*
;*     Device requires 256 bytes of bss space (nh_bss)
;* 
;**************************************************************
;

nh_ayda	equ	0x40		; AY-3-8910 data port
nh_atla	equ	0x41		; AY-3-8910 latch port
nh_hcca	equ	0x80		; Modem data port

nh_fild	equ	0x80		; Default file accress desc

; Driver entry point
; a = Command #
;
; uses: all
nhadev:	ret

; CP/M system hook
; Used to intercept certain syscalls
;
; uses: none if not hooked, all otherwise
nh_sysh:ret
	
; Set up the HCCA modem connection
; Configures the AY-3-8910 to monitor correct interrupts
; and leaves it in a state where the interrupt port is
; exposed
;
; uses: a
nh_hini:ld	a,0x07
	out	(nh_atla),a	; AY register = 7
	ld	a,0x40
	out	(nh_ayda),a	; Configure AY port I/O
	
	ld	a,0x0E
	out	(nh_atla),a	; AY register = 14
	ld	a,0xC0
	out	(nh_ayda),a	; Enable HCCA receive and send
	
	ld	a,0x0F
	out	(nh_atla),a	; AY register = 15
	ret
	
; Loads the GRB into the CCP space
nh_grb:	call	nh_hinit	; Go to HCCA mode
	ld	hl,nh_p1
	ld	de,nh_m0na
	ld	bc,12
	ldir			; Copy name to file open
	call	nh_clos		; Close current file (if any)
	call	nh_open		; Open the file

; Open the prepared file
; Closes the existing file too
;
; uses: af, b, hl
nh_open:ld	hl,nh_m1
	ld	b,4
	call	nh_send
	ld	hl,nh_m0
	ld	b,21
	jp	nh_send
	
; Recives a general response from the NHACP server
; hl = Destination of message
;
; Carry flag set on error
; uses: af, b, hl
nh_rece:call	nh_hcre
	ret	c	; Existing error
	or	a
	scf
	ret	m	; Message to big!
	ld	b,a
	call	nh_hcre
	ret	c	; Existing error
	or	a
	scf
	ret	nz	; Message too big!
nh_rec0:call	nh_hcre
	ret	c	; Error!
	
; Write a number of bytes to the HCCA port
; b = Bytes to write
; hl = Start of message
;
; Carry flag set on error
; uses: af, b, hl
nh_send:ld	a,(hl)
	call	nh_hcwr
	ret	c	; Error!
	djnz	nh_send
	ret
	
; Read from the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
;
; Returns return in a
; Carry flag set on error
; Uses: af
nh_hcre:push	de
	ld	de,0xFFFF
nh_hcr0:in	a,(nh_ayda)
	bit	0,a
	jr	z,nh_hcr0	; Await an interrupt
	bit	1,a
	jr	z,nh_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,nh_hcr0
	scf
	ret			; Timed out waiting
nh_hcr1:in	a,(nh_hcca)
	pop	de
	or	a
	ret
	
; Write to the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
; a = Character to write
;
; Carry flag set on error
; Uses: none
nh_hcwr:push	de
	push	af
	ld	de,0xFFFF
nh_hcw0:in	a,(nh_ayda)
	bit	0,a
	jr	z,nh_hcw0	; Await an interrupt
	bit	1,a
	jr	nz,nh_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,nh_hcw0
	scf
	ret			; Timed out waiting
nh_hcw1:pop	af
	out	(nh_hcca),a
	pop	de
	or	a
	ret
	
; Converts lowercase to uppercase
; a = Character to convert
;
; Returns uppercase in A
; uses: af
nh_ltou:and	0x7F
	cp	0x61		; 'a'
	ret	c
	cp	0x7B		; '{'
	ret	nc
	sub	0x20
	ret
	
; Takes a FCB-style name and formats it to standard notation
; de = Desintation for formatted name
; hl = Source FCB file name
;
; returns flag z if result did not change
; uses: all
nh_form:ld	c,0
	ld	b,8		; Look at all 8 possible name chars
nh_for0:ld	a,(hl)
	call	nh_ltou
	cp	0x21
	jr	c,nh_for1
	call	nh_for3
	djnz	nh_for0
nh_for1:ld	a,0x2E		; '.'
	ld	(de),a
	ld	c,b
	ld	b,0
	add	hl,bc		; Fast forward to extenstion
	ld	b,3		; Copy over extension
nh_for2:ld	a,(hl)
	call	nh_ltou
	call	nh_for3
	djnz	nh_for2
	xor	a		; Zero terminate
	ld	(de),a
	ld	a,c
	or	a
	ret
nh_for3:ex	de,hl
	cp	(hl)		; Increment c if different
	ex	de,hl
	inc	hl
	inc	de
	ret	z
	inc	c
	ret
	
; Path to CP/M image
; Total length: 12 bytes
nh_p0:	defb	'0/CPM22.SYS',0

; Path to GRB image
; Total length: 12 bytes
nh_p1:	defb	'0/FONT.GRB',0,0

; Message prototype to open a file
; Total length: 21 bytes
nh_m0:	defw	0x13		; Message length
	defb	0x01		; Cmd: STORAGE-OPEN
	defb	nh_fild		; Default file descriptor
nh_m0fl:defw	0x00		; Read/Write flags
	defb	0x0E		; Message length
nh_m0na:defb	'0/XXXXXXXXXXXX'; File name field
	defb	0x00		; Padding
	
; Message prototype to close a file
; Total length: 4 bytes
nh_m1:	defw	0x02		; Message length
	defb	0x05		; Cmd: FILE_CLOSE
	defb	nh_fild		; Default file descriptor
	
; Variables
nh_buff	equ	nh_bss