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
	ld	a,0xD0
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
	ld	(tm_curx),hl
	ld	(tm_cura),hl
	ld	(tm_escs),hl
	
	ret


tm_stat:ret


tm_read:ret


tm_writ:call	tm_wri0
	ret
tm_wri0:

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
	

; Updates the cursor animation, assumed 60hz
;
;
tm_ucur:ld	a,(tm_cura)
	or	a
	jr	nz,tm_ucu3
	ld	a,(tm_curc)
	ld	e,a
tm_ucu0:ld	a,(tm_curx)
	ld	c,a
	ld	a,(tm_cury)
	ld	d,a
	call	tm_putc
tm_ucu1:ld	a,(tm_cura)
	inc	a
	cp	60
	jr	nz,tm_ucu2
	xor	a
tm_ucu2:ld	(tm_cura),a
	ret
tm_ucu3:cp	30
	jr	nz,tm_ucu1
	ld	a,(tm_curc)
	xor	0x80
	jr	tm_ucu0
	

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
tm_addr:in	a,(tm_latc)
	ld	a,c
	out	(tm_latc),a
	ld	a,b
	out	(tm_latc),a
	ret
	
; Variables
tm_curx:defb	0	; Cursor X
tm_cury:defb	0	; Cursor Y
tm_cura:defb	0	; Cursor animation
tm_curc:defb	0	; Cursor character
tm_escs:defb	0	; Escape state
tm_aaaa:defb	0	; Not defined yet