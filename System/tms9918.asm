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
tm_read:ld	a,(tm_curx)	; Read the character at cursor
	cp	40
	jr	c,tm_rea0
	sub	40
	ld	hl,0x1000
	jr	tm_rea1
tm_rea0:ld	hl,0x0800
tm_rea1:ld	c,a
	ld	b,0
	add	hl,bc
	ld	c,40
	ld	a,(tm_cury)
tm_rea2:or	a
	jr	z,tm_rea3
	add	hl,bc
	dec	a
	jr	tm_rea2
tm_rea3:ld	b,h
	ld	c,l
	call	tm_addr
	in	a,(tm_data)
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
tm_writ:ld	a,0x1F
	cp	c
	jp	nc,tm_wri0
	ld	e,c
	ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	call	tm_putc		; Write character
	
	; Increment character
	ld	a,(tm_curx)
	inc	a
	ld	(tm_curx),a
	cp	80
	ret	nz
	xor	a
	ld	(tm_curx),a
tm_lf:	ld	a,(tm_cury)
	inc	a
	ld	(tm_cury),a
	cp	24
	ret	nz
	call	tm_dsco
	ld	a,23
	ld	(tm_cury),a
	ret
tm_cr:	xor	a
	ld	(tm_curx),a
	ret
tm_bs:	ld	a,(tm_curx)
	dec	a
	ld	(tm_curx),a
	ret	p
	ld	a,79
	ld	(tm_curx),a
	ld	a,(tm_cury)
	dec	a
	ld	(tm_cury),a
	ret	p
	xor	a
	ld	(tm_curx),a
	ld	(tm_cury),a
	ret
	
	ret
tm_wri0:ld	a,c
	cp	0x0D	; '\r'
	jr	z,tm_cr
	cp	0x0A	; '\n'
	jr	z,tm_lf
	cp	0x08	; '\b'
	jr	z,tm_bs
	ret
	
; Scroll all 3 frame buffers down
;
; uses: af, bc, de, hl
tm_dsco:ld	hl,tmsdev	; Claim cache
	ld	(cache_o),hl
	ld	hl,0x0800+40
	call	tm_dsc0
	ld	hl,0x0C00+40
	call	tm_dsc0
	ld	hl,0x1000+40

	; Shift a buffer down
tm_dsc0:push	hl
	call	tm_addh
	ld	b,4
	ld	hl,cache
tm_dsc1:push	bc
	ld	b,230
	ld	c,tm_data
	inir
	pop	bc
	djnz	tm_dsc1
	xor	a
	ld	b,40
tm_dsc2:ld	(hl),a
	inc	hl
	djnz	tm_dsc2
	pop	hl
	ld	de,0x4000-40
	add	hl,de
	call	tm_addh
	ld	hl,cache
	ld	b,4
tm_dsc3:push	bc
	ld	b,240
	ld	c,tm_data
	otir
	pop	bc
	djnz	tm_dsc3
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
tm_putc:ld	b,0
	ld	a,c
	cp	40
	ld	hl,0x4800	; Place in buffer 0x0800
	call	c,tm_put0	; 0-39 frame
	ld	a,c
	cp	20
	ret	c
	sub	20
	cp	40
	ld	hl,0x4C00	; Place in buffer 0x0800
	call	c,tm_put0	; 20-59 frame
	ld	a,c
	cp	40
	ret	c
	sub	40
	ld	c,a
	ld	hl,0x5000	; Place in buffer 0x1000
	jr	tm_put2

tm_put0:push	bc		
	push	de
	ld	c,a
	call	tm_put2
	pop	de
	pop	bc
	ret

tm_put2:push	hl
tm_put3:xor	a
	cp	d
	jr	z,tm_put4
	dec	d
	ld	hl,40
	add	hl,bc
	ld	b,h
	ld	c,l
	jr	tm_put3
tm_put4:pop	hl
	add	hl,bc
	ld	b,h
	ld	c,l
	call	tm_addr
	ld	a,e
	out	(tm_data),a
	ret

; Clears out all 3 screen buffers
;
; uses: af, bc, de
tm_cls:	ld	bc,0x4800
	call	tm_addr
	ld	c,tm_data
	ld	de,0x0C00
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
	ret
	
; Variables
tm_curx:defb	0	; Cursor X
tm_cury:defb	0	; Cursor Y
tm_outc:defb	0	; Output character
tm_escs:defb	0	; Escape state