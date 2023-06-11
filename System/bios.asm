;
;**************************************************************
;*
;*        B I O S   B O O T   R O U T I N E S
;*
;**************************************************************
;

;
;**************************************************************
;*
;*          B I O S   J U M P   T A B L E
;*
;*    This isn't actually used by the BDOS, but
;*    some applications (*cough* MBASIC) use it
;*    to directly address BIOS calls to get around
;*    the BDOS.
;*
;**************************************************************
;
	jp	boot
wbootin:jp	wboot	; Indirection to wboot, used by MBASIC
	jp	const
	jp	conin
	jp	conout
	jp	list
	jp	punch
	jp	reader
	jp	home
	jp	seldsk
	jp	settrk
	jp	setsec
	jp	setdma
	jp	read
	jp	write
	jp	prstat
	jp	sectrn

; Cold boot entry
; Sets up some lower CP/M memory areas, and tells the INIT
; program to run on CP/M startup.
boot:	ld	sp,cbase

	; Run the warm boot common code
	call	wbootr
	
	; Special conditions for a cold boot
	call	cbinit

	; Jump to CP/M
	ld	c,default
	jp	cbase


; Warm boot entry
; Mainly just calls wbootr and manages IOBYTE
wboot:	ld	sp,cbase

	; Save current drive + user
	ld	a,(tdrive)
	push	af

	; Save IOBYTE
	ld	a,(iobyte)
	push	af

	; Warm boot
	call	wbootr
	
	; Restore IOBYTE
	pop	af
	ld	(iobyte),a
	
	; Restore tdrive and warm boot
	pop	af
	ld	c,a
	jp	cbase

; Warm boot routine
; Sends init signal to device bus, loads CCP, and inits CP/M
; Does not actually jump to CP/M just yet
wbootr:	di
	
	; Zero out BSS
	xor	a
	ld	hl,_TEXT_end
	ld	(hl),a
	ld	de,_TEXT_end+1
	ld	bc,_BSS_size
	ldir

	; Send init signals to all devices
	ld	b,0
wboot0:	push	bc
	ld	hl,bdevsw
	ld	a,b
	call	swindir
	xor	a
	inc	d
	call	z,callmj
	pop	bc
	inc	b
	ld	a,20
	cp	b
	jr	nz,wboot0

	; Turn off batch mode
	ld	a,0
	ld	(batch),a

	; Load the CCP
	call	resccp

	; Call config init
	call	wbinit
	
	; Set up lower memory
	ld	hl,cpmlow
	ld	de,0
	ld	bc,8
	ldir


	; Return
	ret


; This is not a true function, but a block of code to be copied
; to CP/M lower memory
cpmlow:	jp	wbootin	; Call jump table version instead
	defb	0x81	; Default IOBYTE
	defb	0	; Default drive
	jp	fbase-4	; 4 bytes before BDOS entry 


; Console status
;
; Returns a=0xFF if there is a character
; uses: all
; Defaults to device 0 right now
const:	ld	b,0
	call	cdindir
	inc	d
	ret	nz
	inc	a
	jp	callmj
	
; Console read
;
; Returns character in a
; uses: all
; Defaults to device 0 right now
conin:	ld	b,0
	call	cdindir
	inc	d
	ret	nz
	ld	a,2
	jp	callmj
	
; Console write
; c = Character to display
;
; uses: all
; Defaults to device 0 right now
conout:	ld	b,0
chrout:	call	cdindir
	inc	d
	ret	nz
	ld	a,3
	jp	callmj
	
; Printer write
; c = Character to print
;
; uses: all
list:	ld	b,6
	jr	chrout

; Punch (or auxiliary) write
; c = Character to punch
;
punch:	ld	b,4
	jr	chrout

; Reader (or auxiliary) read
;
; Returns character in a, or a=0x1A
reader:	ld	b,2
	call	cdindir
	inc	d
	ld	a,0x1A
	ret	nz
	ld	a,2
	jp	callmj
	
; Move the current drive to track 0
;
; uses: all
home:	ld	a,1
	jp	callbd
	
; Selects a block device
; c = Device to select
; e = Disk logging status
;
; return hl=0 if device not valid
; uses: all
seldsk:	ld	a,c
	ld	b,e
	ld	hl,bdevsw
	call	swindir
	ld	(callbd+1),hl
	ld	hl,0
	inc	d
	ret	nz
	ld	hl,(callmj+1)
	ld	(callbd+4),hl
	ld	a,2
	; Pass b = logging status, c = device #
	
; Small stub to jump to the currently selected block device
; Also records hl as argument
;
; We love self-modfiying code!
callbd:	defb	0x21
	defw	0
	defb	0xC3
	defw	0

; Sets the track of the selected block device
; bc = Track, starts at 0
;
; uses: all
settrk:	ld	a,3
	jr	callbd
	
; Sets the sector of the selected block device
; bc = Sector, starts at 0
;
; uses: all
setsec:	ld	a,4
	jr	callbd

; Sets the DMA address of the selected block device
; bc = DMA address
;
; uses: all
setdma:	ld	h,b
	ld	l,c
	ld	(biodma),hl
	ret
	
; Reads the configured block from the selected block device
;
; uses: all
read:	ld	a,5
	jr	callbd

; Writes the configured block to the selected block device
; c = Deferred mode
;
; uses: all
write:	ld	a,6
	jr	callbd
	
; "Printer" is always read for bytes
; Maybe in the future we will implement this, but for now
; this will do.
;
; Returns a=0xFF
prstat:	ld	a,0xFF
	ret
	
; Provides sector translation
; Returns no translation for all devices
sectrn:	ld	h,b
	ld	l,c
	ret
	
; Character device switch indirection
; Obtains device by doing IOBYTE indirection
; Sets hl to cdevsw and jumps to swindir
cdindir:inc	b
	ld	a,(iobyte)
cdindi0:dec	b
	jr	z,cdindi1
	rra
	jr	cdindi0
cdindi1:and	0x03
	ld	hl,cdevsw

; Switch indirect helper function
; a = Device
; hl = Start of switch
;
; returns d=255 if device found, hl as argument
; uses: af, de, hl
swindir:ld	de,4
	or	a
swindi0:jr	z,swindi1
	add	hl,de
	dec	a
	jr	swindi0
swindi1:ld	a,(hl)
	ld	(callmj+1),a
	inc	hl
	or	(hl)
	ret	z
	ld	a,(hl)
	ld	(callmj+2),a
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	d,255
nulldev:ret		; Just points to a return

; Small stub to jump to the memory jump register
callmj: defb	0xC3
	defw	0



; Variables
biodma:	defw	0	; Block device DMA address