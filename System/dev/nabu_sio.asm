;
;**************************************************************
;*
;*        N A B U   S E R I A L   O P T I O N   C A R D
;*
;*      This driver allows the NABU serial option card to be
;*      used as a bidirectional Ishkur serial device. It will
;*      automatically search for a serial card on init. Serial
;*      cards are numbered by order. The first serial card gets
;*      a minor # of 0, the second card gets a minor number of
;*      1, etc... Up to 4 serial cards are supported.
;* 
;**************************************************************
;
.area	_TEXT



; Driver jump table 
siodev:	or	a
	jr	z,so_init
	dec	a
	jr	z,so_stat
	dec	a
	jr	z,so_read
	jr	so_writ
	
; Device init
; Tries to find the option card if it is installed
; hl = Device options
;
; uses: none
so_init:ld	de,so_atab
	ld	b,l
	inc	b		; Slot 1,2,3,...
	add	hl,de 		; Get address table entry
	ld	c,0xCF		; First slot
	
so_ini0:in	a,(c)
	cp	0x08
	jr	z,so_ini2
	
so_ini1:ld	a,0x10
	add	c
	ret	p		; Can't find, failure
	ld	c,a
	jr	so_ini0
	
so_ini2:djnz	so_ini1		; Repeat if looking for next card
	ld	a,c
	sub	0x0F
	ld	c,a
	ld	(hl),c
	ld	de,so_conf
	ld	b,13
	
	; Lets set up the serial card for 9600 8N1
	; First we set up the 8253, then the 8251
so_ini3:ld	a,(de)
	inc	de
	add	a,(hl)
	ld	c,a
	ld	a,(de)
	inc	de
	out	(c),a
	push	hl
	pop	hl	; Small delay
	djnz	so_ini3
	ret

; Device status 
; hl = Device options
;
; Returns a=0xFF if there is a character to read
; uses: af
so_stat:ld	de,so_atab
	add	hl,de
	xor	a
	cp	(hl)
	ret	z	; No device, return 0
	ld	c,(hl)
	inc	c
so_sta0:in	a,(c)	; Check status register
	and	0x02
	ret	z
	ld	a,0xFF
	ret
	
	
; Waits for a character to come in and returns it
; hl = Device options
;
; Returns ASCII key in A
; uses: af
so_read:ld	de,so_atab
	add	hl,de
	xor	a
	cp	(hl)
	ret	z	; No device, return 0
	ld	c,(hl)
	inc	c
so_rea0:call	so_sta0	; Wait for a character
	jr	z,so_rea0
	dec	c
	in	a,(c)
	ret
	
; Writes a character to the device
; c = Character to write
; hl = Device options
;
; uses: af, bc
so_writ:ld	b,c
	ld	de,so_atab
	add	hl,de
	xor	a
	cp	(hl)
	ret	z	; No device, return 0
	ld	c,(hl)
	inc	c
so_wri0:in	a,(c)
	and	0x01
	jr	z,so_wri0
	dec	c
	out	(c),b
	ret
	
	
; Variables
; 4 possible slots
so_atab:defb	0x00,0x00,0x00,0x00

; Configuration string
; Sets up counters 1 and 2 on the 8523 timer
so_conf:defb	0x07,0x37	; Counter 1 setup
	defb	0x04,0x12
	defb	0x04,0x00
	defb	0x07,0x77	; Counter 2 setup
	defb	0x05,0x12
	defb	0x05,0x00
	
	defb	0x01,0x00	; 8251 setup
	defb	0x01,0x00
	defb	0x01,0x00
	defb	0x01,0x00
	defb	0x01,0x40
	defb	0x01,0x4E
	defb	0x01,0x37