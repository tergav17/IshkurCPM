;
;**************************************************************
;*
;*        N A B U   N H A C P   F I L E   S Y S T E M
;*
;*    Unlike a standard block device, the NFS driver provides
;*    a CP/M filesystem by directly intercepting system calls.
;*    By doing this, it can access provide access to an external
;*    filesystem via NHACP.
;*
;*    Virtual filesystems are directories labelled "A", "B",
;*    "C", etc... on the host system. That are converted to
;*    minor numbers 0, 1, 2, etc... when the driver is being
;*    added to the block device switch  
;* 
;**************************************************************
;

ns_ayda	equ	0x40		; AY-3-8910 data port
ns_atla	equ	0x41		; AY-3-8910 latch port
ns_hcca	equ	0x80		; Modem data port

ns_fild	equ	0x80		; Default file access desc


;
;**************************************************************
;*
;*         D U M M Y   D I S K   G E O M E T R Y
;* 
;**************************************************************
;

; Dummy DPH
ns_dph:defw	0,0,0,0
	defw	dircbuf	; DIRBUF
	defw	ns_dpb	; DPB
	defw	0	; CSV
	defw	ns_alv	; ALV 
	
	
; Dummy format
ns_dpb:	defw	64	; # sectors per track
	defb	3	; BSH
	defb	7	; BLM
	defb	0	; EXM
	defw	1	; DSM
	defw	0	; DRM
	defb	0	; AL0
	defb	0	; AL1
	defw	0	; Size of directory check vector
	defw	0	; Number of reserved tracks at the beginning of disk
	
; Dummy ALV
ns_alv: defb	0

; Driver entry point
; a = Command #
;
; uses: all
nfsdev:	or	a
	jr	z,ns_init
	dec	a
	dec	a
	jr	z,ns_sel
	ld	a,1
	ret

; Inits the device
; Not really needed atm
; c = Logical device #
; hl = Call argument
;
; uses: none
ns_init:ld	a,c
	call	ns_domk
	ld	hl,(ns_mask)
	ld	a,h
	or	b
	ld	h,a
	ld	a,l
	or	c
	ld	l,a
	ld	(ns_mask),hl
	ret


; Selects the drive
; c = Logging status
; hl = Call argument
;
; uses: hl
ns_sel:	ld	de,dirbuf
	ld	hl,ns_dph+8
	ld	bc,8
	ldir
	jp	goback
	

; Set up the HCCA modem connection
; Configures the AY-3-8910 to monitor correct interrupts
; and leaves it in a state where the interrupt port is
; exposed
;
; uses: a
ns_hini:ld	a,0x07
	out	(ns_atla),a	; AY register = 7
	ld	a,0x7F
	out	(ns_ayda),a	; Configure AY port I/O
	
	ld	a,0x0E
	out	(ns_atla),a	; AY register = 14
	ld	a,0xC0
	out	(ns_ayda),a	; Enable HCCA receive and send
	
	ld	a,0x0F
	out	(ns_atla),a	; AY register = 15
	ret
; Loads the CCP into the CCP space
ns_ccp:	ld	hl,ns_p0
	jr	ns_grb0
	
; Loads the GRB into the CCP space
ns_grb:	ld	hl,ns_p1
ns_grb0:ld	de,ns_m0na
	ld	bc,10
	ldir			; Copy name to file open
	call	ns_hini		; Go to HCCA mode
	call	ns_open		; Open the file
	ld	de,0
	ld	hl,cbase
ns_grb1:call	ns_getb
	inc	e
	ld	a,16
	cp	e
	jr	nz,ns_grb1
	ret
	
; CP/M system hook
; Used to intercept certain syscalls
;
; uses: af if not hooked, all otherwise
ns_sysh:ld	a,c
	cp	15
	ret	c		; No syscalls lower than 15
	jr	z,ns_fopn
	ret
	
; Set a 16 bit mask based on a number from 0-15
; a = Bit to set
;
; Returns bit mask in bc
; Uses, af, bc
ns_domk:ld	bc,1
	or	a
ns_dom0:ret	z
	sla	c
	rl	b
	dec	a
	jr	ns_dom0
	
; Check if driver owns device
; Bail if it does not
; If it does, get to logical NHACP device
; de = Address of FCB
;
; Returns logical device in a
; uses: af, hl
ns_ownr:push	bc
	call	ns_getd		; Get FSB device
	call	ns_domk		; Create bitmask
	ld	hl,(ns_mask)
	ld	a,h
	and	b
	jr	nz,ns_own0
	ld	a,l
	and	c
ns_own0:jr	z,ns_exit	; Exit if does not own	
	ld	hl,bdevsw+2
	ld	a,(de)		; Get FSB device
	ld	bc,4
	or	a
ns_own1:jr	z,ns_own2
	add	hl,bc
	dec	a
	jr	ns_own1
ns_own2:ld	a,(hl)		; a = Logical NHACP device
	pop	bc
	ret

; Exit, do not return to caller
ns_exit:pop	bc
	pop	af		; Throw away caller address
	ret

; Gets the logical device number from a FCB
; de = Address of FCB
; 
; Logical device returns in a
; uses: af
ns_getd:ld	a,(de)
	dec	a
	ret	p
	ld	a,(active)
	ret

; Open the prepared file
; Closes the existing file too
;
; uses: af, b, hl
ns_open:ld	hl,ns_m1
	ld	b,6
	call	ns_send
	ld	hl,ns_m0
	ld	b,23
	call	ns_send
	ld	hl,ns_buff
	call	ns_rece
	ret
	
; Gets a block from the currently open file
; and places it in (hl)
; de = Block to read
; hl = Destination for information
;
; Returns location directly after in hl
; Carry flag set on error
; uses: af, b, hl
ns_getb:ex	de,hl
	ld	(ns_m2bn),hl
	ex	de,hl
	push	hl
	ld	hl,ns_m2
	ld	b,12
	call	ns_send
	pop	hl
	ret	c
	call	ns_hcrd
	call	ns_hcre
	ret	c
	cp	0x84
	scf
	jr	nz,ns_get1
	call	ns_hcrd
	ld	b,128
ns_get0:call	ns_hcre
	ret	c
	ld	(hl),a
	inc	hl
	djnz	ns_get0
	or	a
	ret
ns_get1:call	ns_hcrd	; Read the error message and exit
	call	ns_hcre
	scf
	ret
	
; Puts a block into the currently open file
; from that location (hl)
; de = Block to write
; hl = Source of information
;
; Carry flag set on error
; uses: af, b, hl
ns_putb:ex	de,hl
	ld	(ns_m3bn),hl
	ex	de,hl
	push	hl
	ld	hl,ns_m3
	ld	b,12
	call	ns_send		; Send message precursor
	pop	hl
	ret	c
	ld	b,128
ns_put0:ld	a,(hl)		; Send the block
	call	ns_hcwr
	ret	c
	inc	hl
	djnz	ns_put0
	ld	hl,ns_buff
	call	ns_rece
	ld	a,(ns_buff)
	cp	0x81
	ret	z
	scf
	ret
	
; Receives a general response from the NHACP server
; hl = Destination of message
;
; Carry flag set on error
; uses: af, b, hl
ns_rece:call	ns_hcre
	ret	c		; Existing error
	ld	b,a
	call	ns_hcre
	ret	c		; Existing error
	scf
	ret	nz		; Message too big!
ns_rec0:call	ns_hcre
	ret	c		; Error!
	ld	(hl),a
	inc	hl
	djnz	ns_rec0
	or	a
	ret
	
; Write a number of bytes to the HCCA port
; b = Bytes to write
; hl = Start of message
;
; Carry flag set on error
; uses: af, b, hl
ns_send:ld	a,(hl)
	inc	hl
	call	ns_hcwr
	ret	c		; Error!
	djnz	ns_send
	ret
	
; Read from the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
;
; Returns return in a
; Carry flag set on error
; Uses: af
ns_hcrd:call	ns_hcre
ns_hcre:push	de
	ld	de,0x8000
ns_hcr0:in	a,(ns_ayda)
	bit	0,a
	jr	z,ns_hcr0	; Await an interrupt
	bit	1,a
	jr	z,ns_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcr0
	scf
	ret			; Timed out waiting
ns_hcr1:in	a,(ns_hcca)
	pop	de
	or	a
	ret
	
; Write to the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
; a = Character to write
;
; Carry flag set on error
; Uses: f
ns_hcwd:call	ns_hcwr
ns_hcwr:push	de
	push	af
	ld	de,0x80
ns_hcw0:in	a,(ns_ayda)
	bit	0,a
	jr	z,ns_hcw0	; Await an interrupt
	bit	1,a
	jr	nz,ns_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcw0
	scf
	ret			; Timed out waiting
ns_hcw1:pop	af
	out	(ns_hcca),a
	pop	de
	or	a
	ret
	
; Takes a FCB-style name and formats it to standard notation
; a = Logical NHACP device
; de = Desintation for formatted name
; hl = Source FCB file name
;
; uses: all
ns_form:add	a,'A'
	call	ns_for4
	ld	a,'/'
ns_for0:call	ns_for4
	ld	b,8		; Look at all 8 possible name chars
ns_for1:ld	a,(hl)
	call	ns_ltou
	cp	0x21
	jr	c,ns_for2
	call	ns_for4
	inc	hl
	djnz	ns_for1
ns_for2:ld	a,0x2E		; '.'
	call	ns_for4
	ld	c,b
	ld	b,0
	add	hl,bc		; Fast forward to extenstion
	ld	b,3		; Copy over extension
ns_for3:ld	a,(hl)
	call	ns_ltou
	call	ns_for4
	inc	hl
	djnz	ns_for3
	xor	a		; Zero terminate
ns_for4:ex	de,hl
	cp	(hl)
	ex	de,hl
	ld	(de),a
	inc	de
	ret	z
	ld	a,1
	ld	(ns_dore),a
	ret
	
; Path to CP/M image
; Total length: 10 bytes
ns_p0:	defb	'CPM22.SYS',0

; Path to GRB image
; Total length: 10 bytes
ns_p1:	defb	'FONT.GRB',0,0

; Message prototype to open a file
; Total length: 23 bytes
ns_m0:	defb	0x8F,0x00
	defw	19		; Message length
	defb	0x01		; Cmd: STORAGE-OPEN
	defb	ns_fild		; Default file descriptor
ns_m0fl:defw	0x00		; Read/Write flags
	defb	0x0E		; Message length
ns_m0na:defb	'XXXXXXXXXXXXXX'; File name field
	defb	0x00		; Padding
	
; Message prototype to close a file
; Total length: 6 bytes
ns_m1:	defb	0x8F,0x00
	defw	2		; Message length
	defb	0x05		; Cmd: FILE-CLOSE
	defb	ns_fild		; Default file descriptor
	defw	0x00		; Magic bytes
	
; Message prototype to read a block
; Total length: 12 bytes
ns_m2:	defb	0x8F,0x00
	defw	8		; Message length
	defb	0x07		; Cmd: STORAGE-GET-BLOCK
	defb	ns_fild		; Default file descritor
ns_m2bn:defw	0x00,0x00	; Block number
	defw	128		; Block length
	
; Message prototype to write a block
; Total length: 12 bytes
ns_m3:	defb	0x8F,0x00
	defw	136		; Message length
	defb	0x08		; Cmd: STORAGE-PUT-BLOCK
	defb	ns_fild		; Default file descritor
ns_m3bn:defw	0x00,0x00	; Block number
	defw	128		; Block length

; Variables
ns_buff	equ	ns_bss		; Buffer (64b)
ns_mask equ	ns_bss+64	; Ownership mask (2b)
ns_dore	equ	ns_bss+66	; Do reopen?