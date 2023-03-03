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
;**************************************************************
;

; TMS9918 Configuration
tm_data	equ	0xA0	; TMS9918 data register (mode=0)
tm_latc	equ	0xA1	; TMS9917 latch register (mode=1)

tm_keyd	equ	0x90	; Keyboard data register
tm_keys	equ	0x91	; Keyboard status register

; Driver jump table
tmsdev:	jp	tm_init
	jp	tm_stat
	jp	tm_read
	jp	tm_writ
	
tm_test:call	tm_read
	ld	c,a
	call	tm_writ
	jr	tm_test
	
; TMS9918 init
; Load font record, set up terminal
tm_init:call	resgrb

	; Set TMS to text mode
	in	a,(tm_latc)
	ld	a,0x00
	out	(tm_latc),a
	ld	a,0x80
	out	(tm_latc),a
	in	a,(tm_latc)
	ld	a,0xF0
	out	(tm_latc),a
	ld	a,0x81
	out	(tm_latc),a
	
	; Set TMS name table to 0x0800
	in	a,(tm_latc)
	ld	a,0x02
	out	(tm_latc),a
	ld	a,0x82
	out	(tm_latc),a
	
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
	otir
	dec	a
	jr	nz,tm_ini0
	
	; Clear the terminal
	call	tm_cls
	ld	hl,0
	ld	(tm_curx),hl	; curx and cury
	ld	(tm_outc),hl	; curc and escs
	
	ld	a,0xFF
	ld	(tm_outc),a

	ret


; Gets the status of the keyboard
;
; Returns a=0xFF if there is a key to read 
; uses: af
tm_stat:ld	a,(tm_outc)
	inc	a
	ld	a,0xFF
	ret	nz
	call	tm_getc
	ld	(tm_outc),a
	inc	a
	ret	z
	ld	a,0xFF
	ret

; Waits for the user to press a key, and returns it
;
; Returns ASCII key in A
; uses: af, bc, de, hl
tm_read:ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	ld	hl,0x0C00
	ld	a,80
	call	tm_chat
	in	a,(tm_data)	; Key is in A
	ld	d,a
	ld	c,a
	ld	b,1
	
tm_rea4:call	tm_stat
	inc	a
	jr	nz,tm_rea5
	ld	c,d
	call	tm_rea6
	ld	a,(tm_outc)
	ld	b,a
	ld	a,0xFF
	ld	(tm_outc),a
	ld	a,b
	
	; Perform key mapping
	or	a
	jp	p,tm_map0
	xor	a,0
	ret
tm_map0:cp	0x7F	; DEL -> BS
	jr	nz,$+4
	ld	a,8
	ret
	
tm_rea5:call	tm_stal
	djnz	tm_rea4
	ld	a,0x80
	xor	c
	ld	c,a
	ld	b,190
	call	tm_rea6
	jr	tm_rea4


tm_rea6:push	bc
	push	de
	ld	e,c
	ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	call	tm_putc
	pop	de
	pop	bc
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
; uses: af, bc, de, hl
tm_writ:ld	e,c
	ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	call	tm_wri0
	ld	a,b
	ld	(tm_cury),a
	ld	a,c
	ld	(tm_curx),a
	ret
	
; Write helper routine
; c = X position
; d = Y position
; e = Character
;
; Returns b,c as next position
tm_wri0:ld	b,d
	ld	a,0x1F
	cp	e
	jp	nc,tm_wri1
	push	bc
	call	tm_putc		; Write character
	pop	bc
	
	; Increment character
	inc	c
	ld	a,80
	cp	c
	ret	nz
	xor	a
	ld	c,a
tm_lf:  inc	b
	ld	a,24
	cp	b
	ret	nz
	push	bc
	call	tm_dsco
	pop	bc
	dec	b
	ret
tm_cr:	xor	a
	ld	c,a
	ret
tm_bs:	dec	c
	ret	p
	ld	c,79
	dec	b
	ret	p
	xor	a
	ld	b,a
	ld	c,a
	ret

tm_wri1:ld	a,e
	cp	0x0D	; '\r'
	jr	z,tm_cr
	cp	0x0A	; '\n'
	jr	z,tm_lf
	cp	0x08	; '\b'
	jr	z,tm_bs
	ret
	
; Scroll both frame buffers down one
;
; uses: af, bc, de, hl
tm_dsco:ld	hl,0x0800+40
	ld	de,0x4800
	ld	b,24
	call	tm_dsc0
	ld	hl,0x0C00+80
	ld	de,0x4C00
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
; uses: af
tm_getc:in	a,(tm_keys)
	and	2
	dec	a
	ret	m
	in	a,(tm_keyd)
	push	af
	and	0xF0
	cp	0x90
	jr	z,tm_get0
	pop	af
	ret
tm_get0:pop	af
	ld	a,0xFF
	ret

; Puts a character on the screen
; c = X position
; d = Y position
; e = Character to put
;
; uses: af, bc, de, hl
tm_putc:ld	hl,0x4C00
	ld	a,80
	push	bc
	push	de
	call	tm_chat	; Place it in the 80 col buffer
	out	(c),e
	pop	de
	pop	bc
	ld	a,(tm_scro)
	ld	b,a
	ld	a,c
	sub	b	; If character is less than scroll...
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
; uses: af, bc, de, hl
tm_vcpy:call	tm_addh
	ld	b,40
	ld	hl,tm_cbuf
	inir
	ex	de,hl
	call	tm_addh
	ld	b,40
	ld	hl,tm_cbuf
	otir
	ret

; Clears out screen buffer and offscreen buffer
; Also includes clear limited function
;
; uses: af, bc, de
tm_cls:	ld	bc,0x4800
	ld	de,0x0C00
tm_cll:	call	tm_addr
tm_cls0:out	(c),0
	dec	de
	ld	a,d
	or	e
	jr	nz,tm_cls0
	ret

; Sets the TMS address for either reading or writing
; bc = Address 
;
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
	
; Variables
tm_curx:defb	0	; Cursor X
tm_cury:defb	0	; Cursor Y
tm_outc:defb	0	; Output character
tm_scro:defb	0	; Scroll width

; 40 byte character buffer
tm_cbuf:defw	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0