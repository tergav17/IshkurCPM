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
ns_nctl	equ	0x00		; NABU control port

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
; Figures out which devices that the NFS driver "owns"
; b = Logical CP/M device #
; hl = Call argument
;
; uses: none
ns_init:ld	a,b
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
	ld	bc,13
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
	sub	15
	ret	c		; No syscalls lower than 15
	jr	z,ns_fopn	; Open syscall
	dec	a
	jp	z,ns_fcls	; Close syscall (ignored)
	dec	a
	jp	z,ns_sfir	; Search for first syscall
	dec	a
	jp	z,ns_snxt	; Search for next syscall
	ret
	
; Parses the current FCB, and opens the file if it matches
; Note that for the most part this is redundent. The NFS
; driver does not care if a file has been opened before it
; starts reading.
; de = Address of FCB
;
; Uses: all
ns_fopn:call	ns_ownr
	jp	goback
	
; Stub for file close syscall
; Make sure BDOS does not attempt to close a file owned by the driver
;
; Uses: does not matter
ns_fcls:call	ns_ownr
	jp	goback
	
; Search for first file
; Opens up a directory, then skips to routines that read the first dir entry
; de = Address of FCB
;
; Uses: all
ns_sfir:call	ns_ownr
	push	de		; Save de
	ld	hl,ns_m0na
	ex	de,hl
	call	ns_sdir 
	xor	a
	ld	(de),a		; Zero terminate string
	ld	a,1
	ld	(ns_dore),a	; The existing file will be closed unconditionally
	ld	hl,0x0008	; Set flag type to directory
	call	ns_opef		; Call ns_open, but don't set flag
	ld	hl,0x00FF
	ld	(status),hl	; Set status
	jp	nz,goback	; Error if cannot open file
	
	; Send LIST-DIR
	ld	hl,ns_m4
	ld	b,7
	call	ns_send		; Start list-dir command
	ld	hl,ns_buff
	call	ns_rece
	ld	a,(ns_buff)	; Check for errors
	cp	0x81
	jp	nz,goback
	
	; Copy the file pattern end of the input buffer
	pop	hl		; Get the FCB back
	inc	hl
	ld	de,ns_buff+53
	ld	bc,11
	ldir
	
	; Move into ns_snxt
	jr	ns_snx0
	
; Format incoming files into a dir entry
; Will copy over characters until a '.' is reached
; Any remaining characters will be filled out with spaces
; b = Number of characters
; de = Destination of data
; hl = Source of data
ns_ffmt:ld	a,(hl)
	cp	'.'
	jr	nz,ns_ffm0
	dec	hl
	ld	a,' '		; Turn it into a space
ns_ffm0:inc	hl
	ld	(de),a
	inc	de
	djnz	ns_ffmt
	ret
	
; Search for next file
; Takes the open directory and gets the next file
; de = Address of FCB
;
; Uses: all
ns_snxt:call	ns_ownr
	ld	hl,0x00FF
	ld	(status),hl	; Set status

	
ns_snx0:ld	hl,ns_buff	; Clear out the first 53 bytes of the buffer
	ld	a,'.'		; This is to emulate zero termination, due
	ld	(hl),a		; To the fact that NHACP does not zero-terminate
				; strings coming back from the adapter...
	ld	de,ns_buff+1	; I could ask for that to be changed, but I don't 
	ld	bc,52		; want to annoy adapter devs further.
	ldir			; Why am I even saying this, nobody reads this shit anyways...

	; Lets read a directory now
	ld	hl,ns_m5	; Entry point from ns_sfir
	ld	b,7
	call	ns_send		; Get the next file
	ld	hl,ns_buff
	call	ns_rece	
	ld	a,(ns_buff)	; Ensure we got FILE-INFO
	cp	0x86
	jp	nz,goback
	
	; Ok, time to format a directory entry
	ld	hl,ns_buff+22
	ld	de,(biodma)
	ld	a,(userno)
	ld	(de),a		; Set user number
	inc	de
	ld	b,8
	
	; Format first part of file
	call	ns_ffmt
	
	; Now we must skip till we either find a '.'
ns_snx3:ld	a,(hl)
	inc	hl
	cp	'.'
	jr	nz,ns_snx3
	
	; Now the last part
	ld	b,3
	call	ns_ffmt
	
	; Set status to 0
	ld	hl,0
	ld	(status),hl
	jp	goback
	
	
; Set a 16 bit mask based on a number from 0-15
; a = Bit to set
;
; Returns bit mask in bc
; uses: af, bc
ns_domk:ld	bc,1
	or	a
ns_dom0:ret	z
	sla	c
	rl	b
	dec	a
	jr	ns_dom0
	
; Check if driver owns device
; Bail if it does not
; If it does, get the logical NHACP device
; de = Address of FCB
;
; Returns logical device in a
; uses: af, hl
ns_ownr:push	bc
	call	ns_getd		; Get FCB device
	call	ns_domk		; Create bitmask
	ld	hl,(ns_mask)
	ld	a,h
	and	b
	jr	nz,ns_own0
	ld	a,l
	and	c
ns_own0:jr	z,ns_exit	; Exit if does not own	
	ld	hl,bdevsw+2
	call	ns_getd		; Get FCB device
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
; ns_opef can be called to set custom flag
;
; Flag z cleared on error
; uses: af, b, hl
ns_open:ld	hl,0x0001	; Read/Write flag
ns_opef:ld	(ns_m0fl),hl
	ld	hl,ns_m1
	ld	b,6
	call	ns_send
	ld	hl,ns_m0
	ld	b,24
	call	ns_send
	ld	hl,ns_buff
	call	ns_rece
	ld	a,(ns_buff)
	cp	0x83
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
	ld	a,0x09
	out	(ns_nctl),a	; Turn on recv light
	ld	de,0xFFFF
ns_hcr0:in	a,(ns_ayda)
	bit	0,a
	jr	z,ns_hcr0	; Await an interrupt
	bit	1,a
	jr	z,ns_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcr0
ns_hcer:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	scf
	ret			; Timed out waiting
ns_hcr1:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	in	a,(ns_hcca)
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
	ld	de,0xFFFF
	ld	a,0x21
	out	(ns_nctl),a	; Turn on send light
ns_hcw0:in	a,(ns_ayda)
	bit	0,a
	jr	z,ns_hcw0	; Await an interrupt
	bit	1,a
	jr	nz,ns_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcw0
	jr	ns_hcer		; Timed out waiting
ns_hcw1:ld	a,0x01
	out	(ns_nctl),a	; Turn off send light
	pop	af
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
ns_form:call	ns_sdir
	ld	a,'/'
	jp	ns_for4
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
	
; Part of ns_form, but sometimes is called independently
; Sets the directory to access files from
; a = Logical NHACP device
; de = Desintation for formatted name
;
; uses: af, de
ns_sdir:add	a,'A'
	call	ns_for4
	ld	a,(userno)
	add	a,'0'
	cp	':'
	jr	c,ns_for4
	add	a,7
	jr	ns_for4
	
; Converts lowercase to uppercase
; a = Character to convert
;
; Returns uppercase in A
; uses: af
ns_ltou:and	0x7F
	cp	0x61		; 'a'
	ret	c
	cp	0x7B		; '{'
	ret	nc
	sub	0x20
	ret
	
; Path to CP/M image
; Total length: 13 bytes
ns_p0:	defb	'A0/CPM22.SYS',0

; Path to GRB image
; Total length: 13 bytes
ns_p1:	defb	'A0/FONT.GRB',0,0

; Message prototype to open a file
; Total length: 24 bytes
ns_m0:	defb	0x8F,0x00
	defw	20		; Message length
	defb	0x01		; Cmd: STORAGE-OPEN
	defb	ns_fild		; Default file descriptor
ns_m0fl:defw	0x00		; Read/Write flags
	defb	0x0E		; Message length
ns_m0na:defb	'XXXXXXXXXXXXXXX'; File name field
	defb	0x00		; Padding
	
; Message prototype to close a file
; Total length: 6 bytes
ns_m1:	defb	0x8F,0x00
	defw	2		; Message length
	defb	0x05		; Cmd: FILE-CLOSE
	defb	ns_fild		; Default file descriptor
	
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
	
; Message prototype to start a list-dir
; Total length: 7 bytes
ns_m4:	defb	0x8F,0x00
	defw	3		; Message length
	defb	0x0E		; Cmd: LIST-DIR
	defb	ns_fild		; Default file descriptor
	defb	0x00		; Null string
	
; Message prototype to get the next dir entry
; Total length: 7 bytes
ns_m5:	defb	0x8F,0x00
	defw	3		; Message length
	defb	0x0F		; Cmd: GET-DIR-ENTRY
	defb	ns_fild		; Default file descriptor
	defb	28		; Max length of file


; Variables
ns_buff	equ	ns_bss		; Buffer (64b)
ns_mask equ	ns_bss+64	; Ownership mask (2b)
ns_dore	equ	ns_bss+66	; Do reopen?