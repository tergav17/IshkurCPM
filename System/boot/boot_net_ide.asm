;
;**************************************************************
;*
;*        I S H K U R   N E T B O O T   I D E
;*
;*    Reads the first 512 bytes of an IDE device 
;*    and jumps to it. Useful for testing an IDE
;*    device without a modified bootrom.
;*
;**************************************************************
;

nsec	equ	6		; # of BDOS+BIOS sectors 
				; (1024 bytes each)
mem	equ	55		; CP/M image starts at mem*1024
				; Should be same as cpm22.asm
				
aydata	equ	0x40		; AY-3-8910 data port
aylatc	equ	0x41		; AY-3-8910 latch port

id_base	equ	0xC0		; IDE Base address


scratch	equ	0x3000
; NABU bootstrap loads in at 0xB000
entry	equ	0xB000 ; Bootloader entry address



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

	; Select master
	ld	a,0xE0
	out	(id_base+0xC),a
	ld	b,10
	call	id_stal

	; Set up registers
	xor	a
	out	(id_base+0x6),a
	out	(id_base+0x8),a
	out	(id_base+0xA),a
	inc	a
	out	(id_base+0x4),a
	ld	hl,0xC000

	; Read physical
	call	id_rphy

	; Check magic
	ld	hl,(0xC000)
	ld	de,0x0618
	or	a
	sbc	hl,de
	jp	nz,0

	jp	0xC000
	
; Executes a read command
; hl = Destination of data
;
; Returns hl += 512
; uses: af, bc, d, hl
id_rphy:call	id_busy
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
	

code_length: equ $$-code_start
.DEPHASE
