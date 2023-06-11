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
; BSS Segment Variables
.area	_BSS
ns_buff:defs	48	; Buffer (48b)
ns_ptrn:defs	11	; Pattern buffer (11b)
ns_name:defs	11	; Name bufffer (11b)
ns_mask:defs	2	; Ownership mask (2b)
ns_cfcb:defs	2	; Current FCB (2b)
ns_dore:defs	1	; Do reopen? (1b)
ns_isls:defs	1	; Is listing dir? (1b)
ns_tran:defs	1	; Number of bytes in transfer (1b)
.area	_TEXT

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
ns_dph:	defw	0,0,0,0
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
; uses: does not matter
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
; uses: a, b
ns_hini:ld	a,0x07
	out	(ns_atla),a	; AY register = 7
	ld	a,0x7F
	out	(ns_ayda),a	; Configure AY port I/O
	
	; Claim interrupt vectors
	push	hl
	ld	hl,ns_rirq
	ld	(intvec),hl
	ld	hl,ns_wirq
	ld	(intvec+2),hl
	pop	hl
	
; Set interrupts to their default state
;
; uses: a
ns_dflt:ld	a,0x0E
	out	(ns_atla),a	; AY register = 14
	ld	a,0xB0
	out	(ns_ayda),a	; Enable HCCA receive and but not send, plus key and VDP
	
ns_dfl0:ld	a,0x0F		
	out	(ns_atla),a	; AY register = 15
	
	ret

; Set receive and send interrupts
;
; uses: a
ns_esnd:ld	a,0x0E
	out	(ns_atla),a	; AY register = 14
	ld	a,0xC0
	out	(ns_ayda),a	; Enable HCCA receive and send
	jr	ns_dfl0
	
; Set receive but not send interrupt
;
; uses: a
ns_dsnd:ld	a,0x0E
	out	(ns_atla),a	; AY register = 14
	ld	a,0x80
	out	(ns_ayda),a	; Enable HCCA receive and but not send
	jr	ns_dfl0

; Loads the CCP into the CCP space
ns_ccp:	ld	hl,ns_p0
	jr	ns_grb0
	
; Loads the GRB into the CCP space
ns_grb:	ld	hl,ns_p1
ns_grb0:ld	de,ns_m0na
	ld	bc,13
	ldir			; Copy name to file open
	call	ns_hini		; Go to HCCA mode
	ld	hl,0x0000	; O_RDONLY
	call	ns_opef		; Open the file
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
	jr	z,ns_fopn	; Open file
	dec	a
	jp	z,ns_fcls	; Close file
	dec	a
	jp	z,ns_sfir	; Search for first 
	dec	a
	jp	z,ns_snxt	; Search for next 
	dec	a
	jp	z,ns_dele	; Delete file
	dec	a
	jp	z,ns_frea	; File read next record
	dec	a
	jp	z,ns_fwri	; File write next record
	dec	a
	jp	z,ns_fmak	; Create file
	dec	a
	jp	z,ns_frnm	; Rename file
	sub	7
	jr	z,ns_stmp	; Set file attributes (stump)
	sub	3
	jp	z,ns_rrea	; File read random
	dec	a
	jp	z,ns_rwri	; File write random
	dec	a
	jp	z,ns_size	; Compute file size
	dec	a
	jp	z,ns_rrec	; Update random access pointer
	sub	4
	jp	z,ns_rwri	; FIle write random (we will ignore the zero part)
	ret
	
; Stump, do nothing if FCB is owned
; de = Address to FCB
;
; uses: does not matter
ns_stmp:call	ns_ownr

	jp	goback
	
; Parses the current FCB, and searches for a file that matches
; the pattern.
; The point here is to insert the "true" name of the file into
; the FCB so it can be accessed later
; de = Address of FCB
;
; uses: af, bc, de, hl
ns_fopn:call	ns_ownr

	; Go find the file
	push	de
	call	ns_find
	
	; Update status
	ld	hl,0
	ld	(status),hl
	
	; Copy over false CP/M filename to the FCB
	pop	de
	call	ns_nblk		; Get # of blocks
	ld	a,c
	push	de
	inc	de
	ld	hl,ns_name
	ld	bc,11
	ldir
	
	; Set open flag
	ld	c,a
	inc	de
	ld	a,0xE7
	ld	(de),a
	inc	de
	xor	a
	ld	(de),a
	inc	de
	ld	a,c
	ld	(de),a
	inc	de
	
	; Copy over the real filename to the FCB
	ld	bc,16
	ld	hl,ns_buff+22
	ldir
	

	; Check if current
	pop	de
	ld	hl,(ns_cfcb)
	sbc	hl,de
	jr	nz,ns_fop0

	; Set the reopen flag
	ld	a,1
	ld	(ns_dore),a
	
ns_fop0:jp	goback
	
; Close the file
; Main purpose is to ensure that a close on this device is deferred
; Also resets the open flag
; de = Address of DPH
;
; uses: does not matter
ns_fcls:call	ns_ownr

	; Reset open flag
	ld	hl,13
	add	hl,de
	ld	(hl),0x00
	
	; Set flag
	ld	hl,0
	ld	(status),hl

	jp	goback
	
; Function call to start a list-dir operation
; Must be called before a file search
; a = Logical NHACP device
; de = Address of FCB
;
; uses: af, bc, de, hl
ns_slst:push	de		; Save de
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
	
	; Copy the file pattern to the pattern buffer
	pop	hl		; Get the FCB back
	inc	hl
	ld	de,ns_ptrn
	ld	b,11
ns_sls0:ld	a,(hl)
	and	0x7F		; Fix for CP/M stupidness
	ld	(de),a
	inc	de
	inc	hl
	djnz	ns_sls0
	ret

; Does a complete find operation
; Calls ns_slst, and then falls to ns_find
; a = Logical NHACP device
; de = Address of FCB
;
; uses: af, bc, de ,hl
ns_find:call	ns_slst		; Complete find operation
	
; Put the next found file name into the name buffer
; If no more names are found, exit with status of 0x00FF
; ns_slst must have been run to set up state, no more disk operations
; should be been run in the meantime.
; enter into ns_lis0 to avoid setting status
;
; uses: af, bc, de, hl

ns_list:ld	hl,0x00FF
	ld	(status),hl	; Set status

	
ns_lis0:ld	hl,ns_buff	; Clear out the first 40 bytes of the buffer
	xor	a		; This is to emulate zero termination, due
	ld	(hl),a		; To the fact that NHACP does not zero-terminate
	ld	de,ns_buff+1	; strings coming back from the adapter...
	ld	bc,40		
	ldir			

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
	ld	de,ns_name
	ld	b,8
	
	; Format first part of file
	call	ns_ffmt
	
	; Now we must skip till we either find a '.' or a '\0'
ns_lis1:ld	a,(hl)
	or	a
	jr	z,ns_lis2
	inc	hl
	cp	'.'
	jr	nz,ns_lis1
	
	; Now the last part
ns_lis2:ld	b,3
	call	ns_ffmt
	
	; Back dir entry against pattern
	ld	de,ns_ptrn
	ld	hl,ns_name
	ld	b,11

ns_lis3:ld	a,(de)
	ld	c,(hl)
	inc	hl
	inc	de
	cp	'?'
	jr	z,ns_lis4
	cp	c
	jr	nz,ns_lis0
ns_lis4:djnz	ns_lis3
	ret
	
; Search for first file
; Opens up a directory, then skips to routines that read the first dir entry
; de = Address of FCB
;
; uses: all
ns_sfir:xor	a
	ld	(ns_isls),a	; Clear "isls" flag
	call	ns_ownr
	
	; Start the list-dir function
	call	ns_slst
	
	; Set isls flag
	ld	a,1
	ld	(ns_isls),a
	
	; Move into ns_snxt
	jr	ns_snx0
	
; Format incoming files into a dir entry
; Will copy over characters until a '.' or '\0' is reached
; Any remaining characters will be filled out with spaces
; b = Number of characters
; de = Destination of data
; hl = Source of data
;
; uses: af, b, de, hl
ns_ffmt:ld	a,(hl)
	call	ns_ltou
	or	a
	jr	z,ns_ffm0
	cp	'.'
	jr	nz,ns_ffm1
ns_ffm0:dec	hl
	ld	a,' '		; Turn it into a space
ns_ffm1:inc	hl
	ld	(de),a
	inc	de
	djnz	ns_ffmt
	ret
	
; Search for next file
; Takes the open directory and gets the next file
;
; uses: all
ns_snxt:ld	a,(ns_isls)
	or	a
	ret	z
	
	; Set up the HCCA
	call	ns_hini	
	
	; Find the next entry
ns_snx0:call	ns_list
	
	; Copy to directory entry
	ld	de,(biodma)
	ld	a,(userno)
	ld	(de),a
	inc	de
	ld	hl,ns_name
	ld	bc,11
	ldir
	
	; Get file size
	call	ns_nblk
	
	xor	a
	cp	b
	ld	b,16
	jr	nz,ns_snx1
	xor	a
	srl	c
	rla
	srl	c
	rla
	srl	c
	rla
	or	a
	ld	b,c
	jr	z,ns_snx1
	inc	b
	
	
	; Set the records to 0
ns_snx1:ld	c,b
	ld	b,4
	xor	a
ns_snx2:ld	(de),a
	inc	de
	djnz	ns_snx2
	
	; Spoof file size 1-16KB
	ld	b,16
	ld	a,c
ns_snx3:ld	(de),a
	inc	de
	or	a
	jr	z,ns_snx4
	dec	a
ns_snx4:djnz	ns_snx3
	
	; Set status to 0 and return
	ld	hl,0
	ld	(status),hl
	jp	goback
	
; Delete files based on pattern
; Will return error if less than 1 file is found
; de = Address to FCB
;
; uses: all
ns_dele:call	ns_ownr

	; Set first part of remove message prototype
	push	af
	ex	de,hl
	ld	de,ns_m6na
	call	ns_sdir
	ld	a,'/'
	ld	(de),a
	ex	de,hl
	pop	af

	; Start the list-dir function
	call	ns_slst
	
	; Search for the next entry, do not set flag
ns_del0:call	ns_lis0

	; Copy over file name into message
	ld	de,ns_m6na+3
	ld	hl,ns_buff+22
	ld	bc,16
	ldir
	
	; Send delete message
	ld	hl,ns_m6
	ld	b,27
	call	ns_send
	ld	hl,ns_buff
	call	ns_rece
	
	; Set status to 0, and get next element
	ld	hl,0
	ld	(status),hl
	jr	ns_del0

	
; Prepare to access a file
; Checks the magic number to ensure that the file is in fact open
; Also checks ns_dore and ns_cfcb to see if a reopen is required
; If so, copy filename from FCB and do NHACP open
; a = Logical NHACP device
; de = Address of FCB
;
; uses: af, bc, hl
ns_aces:ld	c,a
	ld	hl,13
	add	hl,de
	ld	a,(hl)
	cp	0xE7
	jr	z,ns_ace0
	
	; Return invalid FCB
	ld	hl,9
	ld	(status),hl
	jp	goback
	
	; Check to see if it is currently being accessed
ns_ace0:ld	hl,(ns_cfcb)
	sbc	hl,de
	jr	nz,ns_ace1
	
	; See if a reopen is needed
	ld	a,(ns_dore)
	or	a
	ret	z
	
	; A reopen is needed, do it!
ns_ace1:ld	hl,0x00FF
	ld	(status),hl
	
	; Set the current FCB to this one
	ld	(ns_cfcb),de
	
	; Clear ns_dore flag
	xor	a
	ld	(ns_dore),a
	
	; Copy over the true filename
	ld	hl,16
	add	hl,de
	push	de
	ld	de,ns_m0na
	ld	a,c
	call	ns_sdir
	ld	a,'/'
	ld	(de),a
	inc	de
	ld	bc,16
	ldir
	
	; Now open the file
	call	ns_open
	pop	de
	ret
	
; Takes in a FCB, and returns the current record to access
; de = Address to FCB
;
; Returns record # in bc
; uses: af, bc, hl
ns_gcre:ld	hl,0x0C
	add	hl,de
	ld	b,(hl)
	ld	c,0
	srl	b
	rr	c
	inc	hl
	inc	hl
	ld	a,(hl)
	rlca
	rlca
	rlca
	rlca
	or	b
	ld	b,a
	ld	hl,0x20
	add	hl,de
	ld	a,(hl)
	or	c
	ld	c,a
	ret
	
; Takes in a random record, and writes it to the FCB
; bc = Record #
; de = Address to FCB
;
; uses: af, bc, hl
ns_scre:ld	hl,0x20
	add	hl,de
	ld	a,c
	and	0x7F
	ld	(hl),a
	ld	hl,0x0E
	add	hl,de
	ld	a,b
	rrca
	rrca
	rrca
	rrca
	and	0x0F
	ld	(hl),a
	dec	hl
	dec	hl
	sla	c
	rl	b
	ld	a,b
	and	0x0F
	ld	(hl),a
	ret
		
; Read next record
; Reads the next 128 bytes in a file into the DMA address
; The FCB record count will be incremented by 1
; de = Address of FCB
;
; uses: all
ns_frea:call	ns_ownr

	; Set file up to access
	call	ns_aces
	
	; Get the record to read
	call	ns_gcre
	
	; Set up and do read
	push	bc
	push	de
ns_fre0:ld	d,b
	ld	e,c
	ld	hl,(biodma)
	call	ns_getb
	
	; Make sure there were no issues
ns_fre1:jp	c,goback
	
	; Increment and writeback
	pop	de
	pop	bc
	inc	bc
	call	ns_scre
	
	; Set return status
	ld	hl,0
	ld	a,(ns_tran)
	or	a
	jr	nz,ns_fre2
	inc	hl
	
ns_fre2:ld	(status),hl
	jp	goback
	
; Write next record
; Writes the next 128 bytes into a file from the DMA address
; The FCB record count will be incremented by 1
; de = Address of FCB
;
; uses: all
ns_fwri:call	ns_ownr

	; Set file up to access
	call	ns_aces
	
	; Get the record to write
	call	ns_gcre
	
	; Set up and do write
	push	bc
	push	de
ns_fwr0:ld	d,b
	ld	e,c
	ld	hl,(biodma)
	call	ns_putb
	
	; Set amount transfered to 128
	ld	a,128
	ld	(ns_tran),a
	
	; Continue in read
	jr	ns_fre1
	
; Read record random
; Takes the random address and read a sector from it
ns_rrea:call	ns_ownr

	; Set file up to access
	call	ns_aces
	
	; Decode random address
	call	ns_deco
	dec	bc
	push	bc
	push	de
	inc	bc
	jr	ns_fre0
	
; Write record random
; Takes the random address and write a sector to it
; de = Address to FCB
;
; uses: all
ns_rwri:call	ns_ownr

	; Set file up to access
	call	ns_aces
	
	; Decode random address
	call	ns_deco
	dec	bc
	push	bc
	push	de
	inc	bc
	jr	ns_fwr0
	
; Set random record
; de = Address to FCB
;
; uses: all
ns_rrec:call	ns_ownr
	
	; Get current address from FCB
	call	ns_gcre
	
	; Set FCB random record
	ld	hl,0x21
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	(hl),0
	
	; Done
	jp	goback
	
; Decodes random address
; de = Address to FCB
;
; Returns block number in bc
; uses: af, bc, hl
ns_deco:ld	hl,0x21
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ret
	
; Make new file
; Reboot the system if the file already exists
; de = Address to FCB
;
; uses: all
ns_fmak:call	ns_ownr

	; We either succeed or die trying
	ld	hl,0
	ld	(status),hl

	; Decode filename into open buffer
	ld	hl,ns_m0na
	push	de
	ex	de,hl
	inc	hl
	call	ns_form
	
	; Set the flag and open
	ld	hl,0x0030
	ld	(ns_m0fl),hl
	call	ns_opef
	
	; Error? time to reboot!
	jp	nz,0
	
	; Nope? Activate FCB
	pop	de
	
	; Force reopen
	ld	a,1
	ld	(ns_dore),a
	
	; Do an open
	jp	ns_fopn
	
; Rename file
; Similar to delete, wildcards are allowed
; de = Address to FCB
;
; uses: all
ns_frnm:call	ns_ownr

	; Set first part of rename message prototype
	push	af
	ex	de,hl
	ld	de,ns_m7n0
	call	ns_sdir
	ld	a,'/'
	ld	(de),a
	pop	af
	push	af
	push	hl
	ld	de,17
	add	hl,de
	ld	de,ns_m7n1
	call	ns_form
	pop	de
	pop	af
	

	; Start the list-dir function
	call	ns_slst
	
	; Search for the next entry, do not set flag
ns_frn0:call	ns_lis0

	; Copy over file name into message
	ld	de,ns_m7n0+3
	ld	hl,ns_buff+22
	ld	bc,16
	ldir
	
	; Send rename message
	ld	hl,ns_m7
	ld	b,45
	call	ns_send
	ld	hl,ns_buff
	call	ns_rece
	
	; Set status to 0, and get next element
	ld	hl,0
	ld	(status),hl
	jr	ns_frn0
	
; Place size of file into FCB
; de = Address to FCB
;
; uses: all
ns_size:call	ns_ownr

	; Find file
	push	de
	call	ns_find
	pop	de
	
	; Get number of blocks
	call	ns_nblk
	
	; Set in FCB
	ld	hl,0x21
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	(hl),0

	jp	goback	
	
; Use a FILE-INFO block in ns_buff to calculate
; the number of blocks in a file
;
; Returns number of blocks in bc
; uses: af, bc, hl
ns_nblk:ld	hl,ns_buff+19
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	dec	hl
	ld	a,(hl)
	sla	a
	rl	c
	rl	b
	or	a
	ret	z
	inc	bc
	ret
	
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
ns_own2:call	ns_hini		; We are commited at this point, init HCCA
	ld	a,(hl)		; a = Logical NHACP device
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
ns_open:ld	hl,0x0002	; Read/Write Protect flag
ns_opef:ld	(ns_m0fl),hl
	ld	hl,ns_m1
	ld	b,6
	call	ns_send
	ld	hl,ns_m0
	ld	b,28
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
ns_getb:call	ns_get0
	jp	ns_dflt
ns_get0:ex	de,hl
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
	jr	nz,ns_get2
	call	ns_hcre
	ld	(ns_tran),a
	ld	b,a
	call	ns_hcre
	ld	a,b
	or	a
	ret	z
ns_get1:call	ns_hcre
	ret	c
	ld	(hl),a
	inc	hl
	djnz	ns_get1
	or	a
	ret
ns_get2:call	ns_hcrd	; Read the error message and exit
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
ns_putb:call	ns_put0
	jp	ns_dflt
ns_put0:ex	de,hl
	ld	(ns_m3bn),hl
	ex	de,hl
	push	hl
	ld	hl,ns_m3
	ld	b,12
	call	ns_send		; Send message precursor
	pop	hl
	ret	c
	ld	b,128
ns_put1:ld	a,(hl)		; Send the block
	call	ns_hcwr
	ret	c
	inc	hl
	djnz	ns_put1
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
ns_rece:call	ns_dsnd
	call	ns_rec0
	jp	ns_dflt
ns_rec0:call	ns_hcre
	ret	c		; Existing error
	ld	b,a
	call	ns_hcre
	ret	c		; Existing error
	scf
	ret	nz		; Message too big!
ns_rec1:call	ns_hcre
	ret	c		; Error!
	ld	(hl),a
	inc	hl
	djnz	ns_rec1
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
; Returns result in a
; Carry flag set on error
; Uses: af
ns_hcrd:call	ns_hcre
ns_hcre:xor	a
	ld	(ns_inf),a
	push	de
	ld	a,0x09
	out	(ns_nctl),a	; Turn on recv light
	ld	de,0xFFFF
ns_hcr0:ld	a,(ns_inf)
	or	a
	jr	nz,ns_hcr2
	in	a,(ns_ayda)
	;bit	0,a
	;jr	z,ns_hcr0	; Await an interrupt
	;bit	1,a
	;jr	z,ns_hcr1
	and	0x0F
	xor	0b00000001
	jr	z,ns_hcr1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcr0
ns_hcer:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	scf
	pop	de
	ret			; Timed out waiting
ns_hcr1:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	in	a,(ns_hcca)
	pop	de
	or	a
	ret
ns_hcr2:ld	a,0x01
	out	(ns_nctl),a	; Turn off recv light
	xor	a
	ld	(ns_inf),a
	ld	a,(ns_inb)
	pop	de
	ret
	
; HCCA read interrupt
; Reads from the HCCA, buffers it, and then sets the flag
;
; uses: none
ns_rirq:push	af
	in	a,(ns_hcca)
	ld	(ns_inb),a
	ld	a,1
	ld	(ns_inf),a
	pop	af
	ei
	ret
	
	
; Write to the HCCA port
; Assumes AY is set to reg 15
; Will panic on timeout
; a = Character to write
;
; Carry flag set on error
; Uses: f
ns_hcwr:push	de
	ld	(ns_outb),a
	xor	a
	ld	(ns_outf),a
	call	ns_esnd
	ld	de,0xFFFF
	ld	a,0x21
	out	(ns_nctl),a	; Turn on send light
ns_hcw0:ld	a,(ns_outf)
	or	a
	jr	nz,ns_hcw2
	in	a,(ns_ayda)
	;bit	0,a
	;jr	z,ns_hcw0	; Await an interrupt
	;bit	1,a
	;jr	nz,ns_hcw1
	and	0x0F
	xor	0b00000011
	jr	z,ns_hcw1
	dec	de
	ld	a,e
	or	d
	jr	nz,ns_hcw0
	call	ns_dsnd
	jr	ns_hcer		; Timed out waiting
ns_hcw1:ld	a,(ns_outb)
	out	(ns_hcca),a
ns_hcw2:pop	de
	ld	a,0x01
	out	(ns_nctl),a	; Turn off send light
	call	ns_dsnd
	or	a
	ret
	
; HCCA write interrupt
; Writes to the HCCA from the buffer, and 
ns_wirq:push	af
	ld	a,(ns_outb)
	out	(ns_hcca),a
	ld	a,1
	ld	(ns_outf),a
	call	ns_dsnd		; Y'all can't behave, turning off
	pop	af
	ei
	ret
	
	
; Takes a FCB-style name and formats it to standard notation
; a = Logical NHACP device
; de = Desintation for formatted name
; hl = Source FCB file name
;
; uses: all
ns_form:call	ns_sdir
	ld	a,'/'
	call	ns_wchd
	ld	b,8		; Look at all 8 possible name chars
ns_for1:ld	a,(hl)
	and	0x7F
	call	ns_utol
	cp	0x21
	jr	c,ns_for2
	call	ns_wchd
	inc	hl
	djnz	ns_for1
ns_for2:ld	a,0x2E		; '.'
	call	ns_wchd
	ld	c,b
	ld	b,0
	add	hl,bc		; Fast forward to extenstion
	ld	b,3		; Copy over extension
ns_for3:ld	a,(hl)
	and	0x7F
	call	ns_utol
	cp	0x21
	jr	c,ns_for4
	call	ns_wchd
	inc	hl
	djnz	ns_for3
ns_for4:xor	a		; Zero terminate
	ld	(de),a
	ret
	
; Part of ns_form, but sometimes is called independently
; Sets the directory to access files from
; a = Logical NHACP device
; de = Desintation for formatted name
;
; uses: af, de
ns_sdir:add	a,'A'
	call	ns_wchd
	ld	a,(userno)
	add	a,'0'
	cp	':'
	jr	c,ns_wchd
	add	a,7
	
	; Fall to ns_wchd
	
; Writes a byte to (de), then increments de
; a = Character to write
; de = Destination for character
;
; Returns de=de+1
; uses: af, de
ns_wchd:ld	(de),a
	inc	de
	ret

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
	
; Converts uppercase to lowercase
; a = Character to convert
;
; Returns lowercase in A
; uses: af
ns_utol:and	0x7F
	cp	0x41		; 'A'
	ret	c
	cp	0x5B		; '['
	ret	nc
	add	0x20
	ret
	
; Byte to send out of HCCA
ns_outb:defb	0

; HCCA output flag
ns_outf:defb	0

; Byte received from HCCA
ns_inb:	defb	0

; HCCA input flag
ns_inf: defb	0
	
; Path to CP/M image
; Total length: 13 bytes
ns_p0:	defb	'A0/CPM22.SYS',0

; Path to GRB image
; Total length: 13 bytes
ns_p1:	defb	'A0/FONT.GRB',0,0

; Message prototype to open a file
; Total length: 28 bytes
ns_m0:	defb	0x8F,0x00
	defw	24		; Message length
	defb	0x01		; Cmd: STORAGE-OPEN
	defb	ns_fild		; Default file descriptor
ns_m0fl:defw	0x0000		; Read/Write flags
	defb	19		; File name length
ns_m0na:defs	19,'X'		; File name field
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
	defb	16		; Max length of file
	
; Message prototype to remove a file
; Total length: 27 bytes
ns_m6:	defb	0x8F,0x00
	defw	23		; Message length
	defb	0x10		; Cmd: REMOVE
	defw	0x0000		; Remove regular file
	defb	19		; File name length
ns_m6na:defs	19,'X'		; File name field

; Message prototype to rename a file
; Total length: 45 bytes
ns_m7:	defb	0x8F,0x00
	defw	41		; Message length
	defb	0x11		; Cmd: RENAME
	defb	19		; File name #1 length
ns_m7n0:defs	19,'X'		; File name #1 field
	defb	19		; File name #2 length
ns_m7n1:defs	19,'X'		; File name #2 field
