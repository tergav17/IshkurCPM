;
;**************************************************************
;*
;*      T M S 9 9 1 8   C H A R A C T E R   D E V I C E
;*
;*      This device emulated a VT52 terminal using the
;*      TMS9918A graphics chip. The 2kb font record is
;*      not resident is memory, and must be provided by
;*      a compatable block I/O device.
;*
;*      F18A style 80 column mode is supported
;*
;*      This specific version uses the NABU keyboard as
;*      an input to the emulated termina 
;*
;*      Device requires 48 bytes of bss space (tm_bss)
;* 
;**************************************************************
;
; BSS Segment Variables
.area	_BSS
tm_outc:defs	1	; Output character
tm_scro:defs	1	; Scroll width
tm_escs:defs	1	; Escape state
tm_last:defs	1	; Last character read
tm_cbuf:defs	40	; 40 byte character buffer
.area	_TEXT

; TMS9918 Configuration
tm_data	equ	0xA0	; TMS9918 data register (mode=0)
tm_latc	equ	0xA1	; TMS9918 latch register (mode=1)

tm_keyd	equ	0x90	; Keyboard data register
tm_keys	equ	0x91	; Keyboard status register

tm_ayda	equ	0x40	; AY-3-8910 data port
tm_atla	equ	0x41	; AY-3-8910 latch port

; --- VRAM MAP ---
; 0x0000 - 0x07FF: Font
; 0x0800 - 0x0BFF: 40 column screen buffer
; 0x0C00 - 0x0FFF: Unused
; 0x1000 - 0x17FF: 80 column screen buffer
;
; Serial #
; 0x17FE: 0xE5
; 0x17FF: 0x81


; Driver jump table
vdpdev:	or	a
	jr	z,tm_init
	dec	a
	jr	z,tm_stat
	dec	a
	jp	z,tm_read
	jp	tm_writ

; A slower version of the OTIR instruction
; b = Number of cycles
; c = Output port
; hl = Memory pointer
;
; uses: bc, hl
tm_otir:push	af
tm_oti0:ld	a,(hl)
	out	(c),a
	inc	hl
	djnz	tm_oti0
	pop	af
	ret
	
; A slower version of the INIR instruction
; b = Number of cycles
; c = Output port
; hl = Memory pointer
;
; uses: bc, hl
tm_inir:push	af
tm_inr0:in	a,(c)
	ld	(hl),a
	inc	hl
	djnz	tm_inr0
	pop	af
	ret


; Gets the status of the keyboard
;
; Returns a=0xFF if there is a key to read 
; uses: af, bc, de, hl
tm_stat:ld	a,(tm_last)
	cp	0xE4
	jr	z,tm_scri
	cp	0xE5
	jr	z,tm_sclf
tm_sta0:ld	a,(tm_outc)
	inc	a
	ld	a,0xFF
	ret	nz
	call	tm_getc
	ld	(tm_outc),a
	inc	a
	ret	z
	ld	a,0xFF
	ret

; TMS9918 init
; Load font record, set up terminal
tm_init:call	resgrb

	; Set up registers
	call	tm_setp
	
	; Set up interrupt vectors (if needed)
	ld	hl,tm_virq
	ld	(intvec+6),hl
	ld	hl,tm_kirq
	ld	(intvec+4),hl
	
	; Set TMS pattern generator block to 0
	in	a,(tm_latc)
	xor	a
	out	(tm_latc),a
	ld	a,0x84
	out	(tm_latc),a
	
	; Write the GRB
	ld	bc,0x4000
	call	tm_addr
	ld	hl,cbase
	ld	c,tm_data
	ld	a,8	; Transfer 8*256 = 2048
tm_ini0:ld	b,0
	call	tm_otir
	dec	a
	jr	nz,tm_ini0
	
	; Cold boot?
	ld	a,(tm_cold)
	or	a
	jr	nz,tm_ini1
	
	; Check serial #
	ld	bc,0x17FE
	call	tm_addr
	in	a,(c)
	cp	0xE5
	jr	nz,tm_ini1
	in	a,(c)
	cp	0x81
	jr	z,tm_cloc
	
	; Reset the terminal
tm_ini1:call	tm_cls
	xor	a
	ld	(tm_curx),a
	ld	(tm_cury),a
	ld	(tm_cold),a
	
	; Fall to tm_cloc
	
; Clear the output character
;
; uses: af
tm_cloc:ld	a,0xFF
	ld	(tm_outc),a

	ret
	
; Scroll left / scroll right
;
; uses: af, bc, de, hl
tm_scri:ld	a,(tm_scro)
	or	a
	cp	40
	jr	z,tm_scr1
	add	a,4
tm_scr0:ld	(tm_scro),a
	call	tm_usco
tm_scr1:jr	tm_sta0
tm_sclf:ld	a,(tm_scro)
	or	a
	jr	z,tm_scr1
	sub	4
	jr	tm_scr0

; Sets up registers depending on mode
; used to change between 40-col and 80-col
;
; uses: af, hl
tm_setp:ld	hl,(tm_mode)

	; Set TMS to text mode
	in	a,(tm_latc)
	ld	a,h
	out	(tm_latc),a
	ld	a,0x80
	out	(tm_latc),a
	in	a,(tm_latc)
	ld	a,0xF0
	out	(tm_latc),a
	ld	a,0x81
	out	(tm_latc),a
	
	; Set TMS color
	in	a,(tm_latc)
	ld	a,(tm_colr)
	out	(tm_latc),a
	ld	a,0x87
	out	(tm_latc),a
	
	; Set TMS name table to 0x0800
	in	a,(tm_latc)
	ld	a,l
	out	(tm_latc),a
	ld	a,0x82
	out	(tm_latc),a
	ret

; Waits for the user to press a key, and returns it
;
; Returns ASCII key in A
; uses: af, bc, de, hl
tm_read:ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	ld	hl,0x1000
	ld	a,80
	call	tm_chat
	in	a,(tm_data)	; char is in A
	ld	d,a		; char key
	ld	e,a		; blinking char
	ld	b,1
	
tm_rea0:push	de
	call	tm_stat
	pop	de
	inc	a
	jr	nz,tm_rea1
	ld	e,d
	call	tm_rea2
	ld	a,(tm_outc)
	ld	b,a
	call	tm_cloc
	ld	a,b
	ret
	
tm_rea1:call	tm_stal
	djnz	tm_rea0
	ld	a,0x80
	xor	e
	ld	e,a
	call	tm_rea2
	ld	b,190
	jr	tm_rea0


tm_rea2:push	de
	ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	call	tm_dint
	call	tm_putc
	call	tm_eint
	pop	de
	ret

; Stalls out for a little bit
;
; uses: none
tm_stal:push	bc
	ld	b,255
tm_sta1:push	bc
	pop	bc
	djnz	tm_sta1
	pop	bc
	ret


; Writes a character to the screen
; c = Character to write
;
; Returns c,b as next position 
; uses: af, bc, de, hl
tm_writ:call	tm_dint
	ld	e,c
	ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	call	tm_wri0
	ld	a,b
	ld	(tm_cury),a
	ld	a,c
	ld	(tm_curx),a
	call	tm_eint
	ret
	
; Write helper routine
; c = X position
; d = Y position
; e = Character
;
; Returns c,b as next position
tm_wri0:ld	b,d		; c = X, b = Y
	ld	a,(tm_escs)
	or	a		; Process escape code
	jp	nz,tm_esc
	ld	a,0x1F
	cp	e
	jp	nc,tm_wri1	; Process control code
	push	bc
	call	tm_putc		; Write character
	pop	bc
	
	; Increment character
tm_ri	inc	c
	ld	a,80
	cp	c
	ret	nz
	xor	a
	ld	c,a
tm_lf:  inc	b	; Line feed
	ld	a,24
	cp	b
	ret	nz
	push	bc
	call	tm_dsco
	pop	bc
	dec	b
	ret
tm_cr:	xor	a	; Carriage return
	ld	c,a
	ret
tm_bs:	dec	c	; Backspace 
	ret	p
	ld	c,79
	dec	b
	ret	p
	xor	a
	ld	b,a
	ld	c,a
	ret
tm_up:	xor	a	; Move up
	cp	b
	ret	z
	dec	b
	ret
tm_cshm:call	tm_cls
tm_home:xor	a
	ld	b,a
	ld	c,a
	ret

tm_wri1:ld	a,e
	cp	0x08	; '\b' (Cursor left)
	jr	z,tm_bs
	cp	0x12	; Cursor right
	jr	z,tm_ri
	cp	0x0A	; '\n' (Cursor down)
	jr	z,tm_lf
	cp	0x0B	; Cursor up
	jr	z,tm_up
	cp	0x0D	; '\r' 
	jr	z,tm_cr
	cp	0x17	; Clear end of screen
	jr	z,tm_cles
	cp	0x18	; Clear end of line
	jr	z,tm_clea
	cp	0x1A	; Clear screen, home cursor
	jr	z,tm_cshm
	cp	0x1E	; Home cursor
	jr	z,tm_home
	cp	0x1B	; Escape
	ret	nz
	ld	a,1
	ld	(tm_escs),a
	ret
	
	; Handle escape sequence
tm_esc:	dec	a
	jr	z,tm_esc0
	dec	a
	jr	z,tm_esc1
	dec	a
	jr	z,tm_esc2
	dec	a
	jr	z,tm_updc
tm_escd:xor	a	; Escape done
tm_escr:ld	(tm_escs),a
	ret
tm_esc0:ld	a,0xFF	; Do 40-col
	cp	e
	jr	z,tm_40c
	ld	a,0xFE	; Do 80-col
	cp	e
	jr	z,tm_80c
	ld	a,0xFD	; Set color
	cp	e
	jr	z,tm_scol
	ld	a,0x3D	; '='
	cp	e
	jr	nz,tm_escd
tm_esci:ld	a,(tm_escs)
	inc	a
	jr	tm_escr
tm_esc1:ld	a,e
	ld	e,0x20
	sub	e
	cp	24
	jr	nc,tm_escd
	ld	b,a
	jr	tm_esci
tm_esc2:ld	a,e
	ld	e,0x20
	sub	e
	cp	80
	jr	nc,tm_escd
	ld	c,a
	jr	tm_escd
	
	; Clear segment
	; B = ending line
tm_cles:ld	b,23
tm_clea:inc	b
	ld	e,0
	push	bc
	push	de
	ld	a,80
	ld	hl,0x5000
	call	tm_chat
	pop	de
	pop	bc
tm_cle0:xor	a
	out	(tm_data),a
	inc	c
	ld	a,80
	cp	c
	jr	nz,tm_cle0
	inc	d
	xor	a
	ld	c,a
	ld	a,d
	cp	b
	jr	nz,tm_cle0
	pop	de	; Do not update character
	jp	tm_usco
	
tm_40c:	push	hl
	ld	hl,0x0002
tm_cupd:ld	(tm_mode),hl
	call	tm_setp
	pop	hl
	jr	tm_escd
	
tm_80c:	push	hl
	ld	hl,0x0407
	jr	tm_cupd
	
	; Set color command
tm_scol:ld	a,4
	jr	tm_escr
	
	; Update color here
tm_updc:ld	a,e
	ld	(tm_colr),a
	call	tm_setp
	jr	tm_escd
	
	
	
; Scroll both frame buffers down one
;
; uses: af, bc, de, hl
tm_dsco:ld	hl,0x0800+40
	ld	de,0x4800
	ld	b,24
	call	tm_dsc0
	ld	hl,0x1000+80
	ld	de,0x5000
	ld	b,48
tm_dsc0:push	bc
	push	de
	push	hl
	call	tm_vcpy
	pop	hl
	pop	de
	ld	bc,40
	add	hl,bc
	ex	de,hl
	add	hl,bc
	ex	de,hl
	pop	bc
	djnz	tm_dsc0
	ret
	

; Grabs the latest key pressed by the keyboard
; Discard keyboard errors
; Returns key in A, or 0xFF if none
;
; uses: af, bc, de, hl
tm_getc:ld	a,(tm_inf)
	or	a
	ld	a,0
	ld	(tm_inf),a
	ld	a,(tm_inb)
	jr	nz,tm_get0

	in	a,(tm_keys)
	and	2
	dec	a
	ret	m
	
	; Grab the key
	in	a,(tm_keyd)
tm_get0:ld	(tm_last),a
	call	tm_map
	ld	a,c
	ret
	
; Handles a keyboard interrupt for the VDP terminal driver
; Keypress stored in tm_inb and tm_inf flag is set
; 
; uses: none
tm_kirq:push	af
	in	a,(tm_keyd)
	ld	(tm_inb),a
	ld	a,1
	ld	(tm_inf),a
	pop	af
	ei
	ret
	
	
; Maps keyboard input to ASCII
; a = Key to map
;
; Returns mapped key in c
; uses: af, c
tm_map:	ld	c,a
	
	; Mapping function
	ld	hl,tm_mapt
tm_map0:ld	a,(hl)
	or	a
	jr	z,tm_map2
	cp	c
	inc	hl
	ld	a,(hl)
	inc	hl
	jr	nz,tm_map0
	ld	c,a
	ret
	
	
	; Filter non-ASCII
tm_map2:ld	a,c
	and	0x80	
	ret	z
	ld	c,0xFF
	ret
	
; Map table
tm_mapt:defb	0x7F,0x08	; DEL -> BS
	defb	0xE1,0x08	; '<-' -> BS
	defb	0xEA,0x7F	; TV -> DEL
	defb	0xE0,0x0C	; '->' -> Right
	defb	0xE2,0x0B	; '/\' -> Up
	defb	0xE3,0x0A	; '\/' -> Linefeed 
	defb	0xE9,0x5C	; PAUSE -> '\'
	defb	0xE8,0x60	; SYM -> '@'
	defb	0xE6,0x7C	; NO -> '|'
	defb	0xE7,0x7E	; YES -> '~'
	defb	0

; Puts a character on the screen
; c = X position
; d = Y position
; e = Character to put
;
; uses: af, bc, de, hl
tm_putc:ld	hl,0x5000
	ld	a,80
	push	bc
	push	de
	call	tm_chat	; Place it in the 80 col buffer
	out	(c),e
	pop	de
	pop	bc
tm_putf:ld	a,(tm_scro)	; Place into frame buffer
	ld	b,a
	ld	a,c
	sub	b	; If character is less than scroll...
	ld	c,a
	ret	m
	cp	40	; If desired position is 40 or more
	ret	nc
	ld	hl,0x4800
	ld	a,40
	call	tm_chat	; Place it in the 40 col screen buffer
	out	(c),e
	ret

; Sets the TMS address to a character at x,y
; a = Line width
; c = X position
; d = Y position
; hl = Buffer address
;
; uses: af, bc, d, hl
tm_chat:ld	b,0
	add	hl,bc
	ld	c,a
	xor	a
	cp	d
tm_cha0:jr	z,tm_addh
	add	hl,bc
	dec	d
	jr	tm_cha0

; Copies VRAM from one location to another
; Transfers occur in blocks of 40 bytes
; de = destination address
; hl = source location
;
; b = 0 on return
; uses: af, bc, de, hl
tm_vcpy:call	tm_addh
	ld	b,40
	ld	hl,tm_cbuf
	call	tm_inir
	ex	de,hl
	call	tm_addh
	ld	b,40
	ld	hl,tm_cbuf
	call	tm_otir
	ret
	
; Updates the frame buffer based on the scroll position
;
; uses: af, bc, de, hl
tm_usco:ld	hl,0x1000
	ld	de,0x4800
	ld	a,(tm_scro)
	ld	b,0
	ld	c,a
	add	hl,bc
	ld	b,24
tm_usc0:push	bc
	push	de
	push	hl
	call	tm_vcpy
	pop	hl
	pop	de
	ld	c,80
	add	hl,bc
	ex	de,hl
	ld	c,40
	add	hl,bc
	ex	de,hl
	pop	bc
	djnz	tm_usc0
	ret
	

; Clears out screen buffer and offscreen buffer
; Also includes clear limited function
;
; uses: af, bc, de
tm_cls:	ld	bc,0x4800
	ld	de,0x1000-2
	call	tm_addr
tm_cls0:out	(c),0
	dec	de
	ld	a,d
	or	e
	jr	nz,tm_cls0
	
	; Write super special serial #
	ld	a,0xE5
	out	(c),a
	push	af
	pop	af
	ld	a,0x81
	out	(c),a
	ret

; Sets the TMS address for either reading or writing
; bc = Address 
;
; Returns tm_data in c
; uses: af, bc
tm_addh:ld	b,h		; Does HL instead of BC
	ld	c,l
tm_addr:in	a,(tm_latc)
	ld	a,c
	out	(tm_latc),a
	ld	a,b
	out	(tm_latc),a
	ld	c,tm_data
	ret
	
; Handles a TMS9918 irq
tm_virq:push	af
	in	a,(tm_latc)
	pop	af
	ei
	ret
	
	
; Disables all interrupts while VDP operations occur
;
; uses: a
tm_dint:ld	a,0x0E
	out	(tm_atla),a	; AY register = 14
	ld	a,0x00
	out	(tm_ayda),a	
	ret
	
; Enables interrupts again
;
; uses: a
tm_eint:ld	a,0x0E
	out	(tm_atla),a	; AY register = 14
	ld	a,0xB0
	out	(tm_ayda),a
	ret
	
; Variables
tm_mode:defw	0x0002
tm_colr:defb	0xE1
tm_inb:	defb	0
tm_inf:	defb	0
tm_curx:defb	0
tm_cury:defb	0
tm_cold:defb	1