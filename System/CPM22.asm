;**************************************************************
;*
;*             C P / M   version   2 . 2
;*
;*   Reconstructed from memory image on February 27, 1981
;*
;*                by Clark A. Calkins
;*
;*      Modified to build as single image from source
;*
;**************************************************************
;
;   Set memory base here. 
;
mem	equ	58		;CP/M image starts at mem*1024
;
iobyte	equ	3		;i/o definition byte.
tdrive	equ	4		;current drive name and user number.
entry	equ	5		;entry point for the cp/m bdos.
tfcb	equ	5ch		;default file control block.
tbuff	equ	80h		;i/o buffer and command line storage.
tbase	equ	100h		;transiant program storage area.
;
;   set control character equates.
;
cntrlc	equ	3		;control-c
cntrle	equ	05h		;control-e
bs	equ	08h		;backspace
tab	equ	09h		;tab
lf	equ	0ah		;line feed
ff	equ	0ch		;form feed
cr	equ	0dh		;carriage return
cntrlp	equ	10h		;control-p
cntrlr	equ	12h		;control-r
cntrls	equ	13h		;control-s
cntrlu	equ	15h		;control-u
cntrlx	equ	18h		;control-x
cntrlz	equ	1ah		;control-z (end-of-file mark)
del	equ	7fh		;rubout
;
;   set origin for cp/m
;
	org	(mem)*1024
;
cbase:	jp	command		;execute command processor (ccp).
	jp	clearbuf	;entry to empty input buffer before starting ccp.
	jp	boot

;
;   standard cp/m ccp input buffer. format is (max length),
; (actual length), (char #1), (char #2), (char #3), etc.
;
inbuff:	defb	127		;length of input buffer.
	defb	0		;current length of contents.
	defb	'Copyright'
	defb	' 1979 (c) by Digital Research      '
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
inpoint:defw	inbuff+2	;input line pointer
namepnt:defw	0		;input line pointer used for error message. points to
;			;start of name in error.
;
;   routine to print (a) on the console. all registers used.
;
print:	ld	e,a		;setup bdos call.
	ld	c,2
	jp	entry
;
;   routine to print (a) on the console and to save (bc).
;
printb:	push	bc
	call	print
	pop	bc
	ret	
;
;   routine to send a carriage return, line feed combination
; to the console.
;
crlf:	ld	a,cr
	call	printb
	ld	a,lf
	jp	printb
;
;   routine to send one space to the console and save (bc).
;
space:	ld	a,' '
	jp	printb
;
;   routine to print character string pointed to be (bc) on the
; console. it must terminate with a null byte.
;
pline:	push	bc
	call	crlf
	pop	hl
pline2:	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	push	hl
	call	print
	pop	hl
	jp	pline2
;
;   routine to reset the disk system.
;
resdsk:	ld	c,13
	jp	entry
;
;   routine to select disk (a).
;
dsksel:	ld	e,a
	ld	c,14
	jp	entry
;
;   routine to call bdos and save the return code. the zero
; flag is set on a return of 0ffh.
;
entry1:	call	entry
	ld	(rtncode),a	;save return code.
	inc	a		;set zero if 0ffh returned.
	ret	
;
;   routine to open a file. (de) must point to the fcb.
;
open:	ld	c,15
	jp	entry1
;
;   routine to open file at (fcb).
;
openfcb:xor	a		;clear the record number byte at fcb+32
	ld	(fcb+32),a
	ld	de,fcb
	jp	open
;
;   routine to close a file. (de) points to fcb.
;
close:	ld	c,16
	jp	entry1
;
;   routine to search for the first file with ambigueous name
; (de).
;
srchfst:ld	c,17
	jp	entry1
;
;   search for the next ambigeous file name.
;
srchnxt:ld	c,18
	jp	entry1
;
;   search for file at (fcb).
;
srchfcb:ld	de,fcb
	jp	srchfst
;
;   routine to delete a file pointed to by (de).
;
delete:	ld	c,19
	jp	entry
;
;   routine to call the bdos and set the zero flag if a zero
; status is returned.
;
entry2:	call	entry
	or	a		;set zero flag if appropriate.
	ret	
;
;   routine to read the next record from a sequential file.
; (de) points to the fcb.
;
rdrec:	ld	c,20
	jp	entry2
;
;   routine to read file at (fcb).
;
readfcb:ld	de,fcb
	jp	rdrec
;
;   routine to write the next record of a sequential file.
; (de) points to the fcb.
;
wrtrec:	ld	c,21
	jp	entry2
;
;   routine to create the file pointed to by (de).
;
create:	ld	c,22
	jp	entry1
;
;   routine to rename the file pointed to by (de). note that
; the new name starts at (de+16).
;
renam:	ld	c,23
	jp	entry
;
;   get the current user code.
;
getusr:	ld	e,0ffh
;
;   routne to get or set the current user code.
; if (e) is ff then this is a get, else it is a set.
;
getsetuc: ld	c,32
	jp	entry
;
;   routine to set the current drive byte at (tdrive).
;
setcdrv:call	getusr		;get user number
	add	a,a		;and shift into the upper 4 bits.
	add	a,a
	add	a,a
	add	a,a
	ld	hl,cdrive	;now add in the current drive number.
	or	(hl)
	ld	(tdrive),a	;and save.
	ret	
;
;   move currently active drive down to (tdrive).
;
movecd:	ld	a,(cdrive)
	ld	(tdrive),a
	ret	
;
;   routine to convert (a) into upper case ascii. only letters
; are affected.
;
upper:	cp	'a'		;check for letters in the range of 'a' to 'z'.
	ret	c
	cp	'{'
	ret	nc
	and	5fh		;convert it if found.
	ret	
;
;   routine to get a line of input. we must check to see if the
; user is in (batch) mode. if so, then read the input from file
; ($$$.sub). at the end, reset to console input.
;
getinp:	ld	a,(batch)	;if =0, then use console input.
	or	a
	jp	z,getinp1
;
;   use the submit file ($$$.sub) which is prepared by a
; submit run. it must be on drive (a) and it will be deleted
; if and error occures (like eof).
;
	ld	a,(cdrive)	;select drive 0 if need be.
	or	a
	ld	a,0		;always use drive a for submit.
	call	nz,dsksel	;select it if required.
	ld	de,batchfcb
	call	open		;look for it.
	jp	z,getinp1	;if not there, use normal input.
	ld	a,(batchfcb+15)	;get last record number+1.
	dec	a
	ld	(batchfcb+32),a
	ld	de,batchfcb
	call	rdrec		;read last record.
	jp	nz,getinp1	;quit on end of file.
;
;   move this record into input buffer.
;
	ld	de,inbuff+1
	ld	hl,tbuff	;data was read into buffer here.
	ld	b,128		;all 128 characters may be used.
	call	hl2de		;(hl) to (de), (b) bytes.
	ld	hl,batchfcb+14
	ld	(hl),0		;zero out the 's2' byte.
	inc	hl		;and decrement the record count.
	dec	(hl)
	ld	de,batchfcb	;close the batch file now.
	call	close
	jp	z,getinp1	;quit on an error.
	ld	a,(cdrive)	;re-select previous drive if need be.
	or	a
	call	nz,dsksel	;don't do needless selects.
;
;   print line just read on console.
;
	ld	hl,inbuff+2
	call	pline2
	call	chkcon		;check console, quit on a key.
	jp	z,getinp2	;jump if no key is pressed.
;
;   terminate the submit job on any keyboard input. delete this
; file such that it is not re-started and jump to normal keyboard
; input section.
;
	call	delbatch	;delete the batch file.
	jp	cmmnd1		;and restart command input.
;
;   get here for normal keyboard input. delete the submit file
; incase there was one.
;
getinp1:call	delbatch	;delete file ($$$.sub).
	call	setcdrv		;reset active disk.
	ld	c,10		;get line from console device.
	ld	de,inbuff
	call	entry
	call	movecd		;reset current drive (again).
;
;   convert input line to upper case.
;
getinp2:ld	hl,inbuff+1
	ld	b,(hl)		;(b)=character counter.
getinp3:inc	hl
	ld	a,b		;end of the line?
	or	a
	jp	z,getinp4
	ld	a,(hl)		;convert to upper case.
	call	upper
	ld	(hl),a
	dec	b		;adjust character count.
	jp	getinp3
getinp4:ld	(hl),a		;add trailing null.
	ld	hl,inbuff+2
	ld	(inpoint),hl	;reset input line pointer.
	ret	
;
;   routine to check the console for a key pressed. the zero
; flag is set is none, else the character is returned in (a).
;
chkcon:	ld	c,11		;check console.
	call	entry
	or	a
	ret	z		;return if nothing.
	ld	c,1		;else get character.
	call	entry
	or	a		;clear zero flag and return.
	ret	
;
;   routine to get the currently active drive number.
;
getdsk:	ld	c,25
	jp	entry
;
;   set the stabdard dma address.
;
stddma:	ld	de,tbuff
;
;   routine to set the dma address to (de).
;
dmaset:	ld	c,26
	jp	entry
;
;  delete the batch file created by submit.
;
delbatch: ld	hl,batch	;is batch active?
	ld	a,(hl)
	or	a
	ret	z
	ld	(hl),0		;yes, de-activate it.
	xor	a
	call	dsksel		;select drive 0 for sure.
	ld	de,batchfcb	;and delete this file.
	call	delete
	ld	a,(cdrive)	;reset current drive.
	jp	dsksel
;
;   check to two strings at (pattrn1) and (pattrn2). they must be
; the same or we halt....
;
verify:	ld	de,pattrn1	;these are the serial number bytes.
	ld	hl,pattrn2	;ditto, but how could they be different?
	ld	b,6		;6 bytes each.
verify1:ld	a,(de)
	cp	(hl)
	jp	nz,halt		;jump to halt routine.
	inc	de
	inc	hl
	dec	b
	jp	nz,verify1
	ret	
;
;   print back file name with a '?' to indicate a syntax error.
;
synerr:	call	crlf		;end current line.
	ld	hl,(namepnt)	;this points to name in error.
synerr1:ld	a,(hl)		;print it until a space or null is found.
	cp	' '
	jp	z,synerr2
	or	a
	jp	z,synerr2
	push	hl
	call	print
	pop	hl
	inc	hl
	jp	synerr1
synerr2:ld	a,'?'		;add trailing '?'.
	call	print
	call	crlf
	call	delbatch	;delete any batch file.
	jp	cmmnd1		;and restart from console input.
;
;   check character at (de) for legal command input. note that the
; zero flag is set if the character is a delimiter.
;
check:	ld	a,(de)
	or	a
	ret	z
	cp	' '		;control characters are not legal here.
	jp	c,synerr
	ret	z		;check for valid delimiter.
	cp	'='
	ret	z
	cp	'_'
	ret	z
	cp	'.'
	ret	z
	cp	':'
	ret	z
	cp	';'
	ret	z
	cp	'<'
	ret	z
	cp	'>'
	ret	z
	ret	
;
;   get the next non-blank character from (de).
;
nonblank: ld	a,(de)
	or	a		;string ends with a null.
	ret	z
	cp	' '
	ret	nz
	inc	de
	jp	nonblank
;
;   add (hl)=(hl)+(a)
;
addhl:	add	a,l
	ld	l,a
	ret	nc		;take care of any carry.
	inc	h
	ret	
;
;   convert the first name in (fcb).
;
convfst:ld	a,0
;
;   format a file name (convert * to '?', etc.). on return,
; (a)=0 is an unambigeous name was specified. enter with (a) equal to
; the position within the fcb for the name (either 0 or 16).
;
convert:ld	hl,fcb
	call	addhl
	push	hl
	push	hl
	xor	a
	ld	(chgdrv),a	;initialize drive change flag.
	ld	hl,(inpoint)	;set (hl) as pointer into input line.
	ex	de,hl
	call	nonblank	;get next non-blank character.
	ex	de,hl
	ld	(namepnt),hl	;save pointer here for any error message.
	ex	de,hl
	pop	hl
	ld	a,(de)		;get first character.
	or	a
	jp	z,convrt1
	sbc	a,'a'-1		;might be a drive name, convert to binary.
	ld	b,a		;and save.
	inc	de		;check next character for a ':'.
	ld	a,(de)
	cp	':'
	jp	z,convrt2
	dec	de		;nope, move pointer back to the start of the line.
convrt1:ld	a,(cdrive)
	ld	(hl),a
	jp	convrt3
convrt2:ld	a,b
	ld	(chgdrv),a	;set change in drives flag.
	ld	(hl),b
	inc	de
;
;   convert the basic file name.
;
convrt3:ld	b,08h
convrt4:call	check
	jp	z,convrt8
	inc	hl
	cp	'*'		;note that an '*' will fill the remaining
	jp	nz,convrt5	;field with '?'.
	ld	(hl),'?'
	jp	convrt6
convrt5:ld	(hl),a
	inc	de
convrt6:dec	b
	jp	nz,convrt4
convrt7:call	check		;get next delimiter.
	jp	z,getext
	inc	de
	jp	convrt7
convrt8:inc	hl		;blank fill the file name.
	ld	(hl),' '
	dec	b
	jp	nz,convrt8
;
;   get the extension and convert it.
;
getext:	ld	b,03h
	cp	'.'
	jp	nz,getext5
	inc	de
getext1:call	check
	jp	z,getext5
	inc	hl
	cp	'*'
	jp	nz,getext2
	ld	(hl),'?'
	jp	getext3
getext2:ld	(hl),a
	inc	de
getext3:dec	b
	jp	nz,getext1
getext4:call	check
	jp	z,getext6
	inc	de
	jp	getext4
getext5:inc	hl
	ld	(hl),' '
	dec	b
	jp	nz,getext5
getext6:ld	b,3
getext7:inc	hl
	ld	(hl),0
	dec	b
	jp	nz,getext7
	ex	de,hl
	ld	(inpoint),hl	;save input line pointer.
	pop	hl
;
;   check to see if this is an ambigeous file name specification.
; set the (a) register to non zero if it is.
;
	ld	bc,11		;set name length.
getext8:inc	hl
	ld	a,(hl)
	cp	'?'		;any question marks?
	jp	nz,getext9
	inc	b		;count them.
getext9:dec	c
	jp	nz,getext8
	ld	a,b
	or	a
	ret	
;
;   cp/m command table. note commands can be either 3 or 4 characters long.
;
numcmds equ	6		;number of commands
cmdtbl:	defb	'dir '
	defb	'era '
	defb	'type'
	defb	'save'
	defb	'ren '
	defb	'user'
;
;   the following six bytes must agree with those at (pattrn2)
; or cp/m will halt. why?
;
pattrn1:defb	0,22,0,0,0,0	;(* serial number bytes *).
;
;   search the command table for a match with what has just
; been entered. if a match is found, then we jump to the
; proper section. else jump to (unknown).
; on return, the (c) register is set to the command number
; that matched (or numcmds+1 if no match).
;
search:	ld	hl,cmdtbl
	ld	c,0
search1:ld	a,c
	cp	numcmds		;this commands exists.
	ret	nc
	ld	de,fcb+1	;check this one.
	ld	b,4		;max command length.
search2:ld	a,(de)
	cp	(hl)
	jp	nz,search3	;not a match.
	inc	de
	inc	hl
	dec	b
	jp	nz,search2
	ld	a,(de)		;allow a 3 character command to match.
	cp	' '
	jp	nz,search4
	ld	a,c		;set return register for this command.
	ret	
search3:inc	hl
	dec	b
	jp	nz,search3
search4:inc	c
	jp	search1
;
;   set the input buffer to empty and then start the command
; processor (ccp).
;
clearbuf: xor	a
	ld	(inbuff+1),a	;second byte is actual length.
;
;**************************************************************
;*
;*
;* C C P  -   C o n s o l e   C o m m a n d   P r o c e s s o r
;*
;**************************************************************
;*
command:ld	sp,ccpstack	;setup stack area.
	push	bc		;note that (c) should be equal to:
	ld	a,c		;(uuuudddd) where 'uuuu' is the user number
	rra			;and 'dddd' is the drive number.
	rra	
	rra	
	rra	
	and	0fh		;isolate the user number.
	ld	e,a
	call	getsetuc	;and set it.
	call	resdsk		;reset the disk system.
	ld	(batch),a	;clear batch mode flag.
	pop	bc
	ld	a,c
	and	0fh		;isolate the drive number.
	ld	(cdrive),a	;and save.
	call	dsksel		;...and select.
	ld	a,(inbuff+1)
	or	a		;anything in input buffer already?
	jp	nz,cmmnd2	;yes, we just process it.
;
;   entry point to get a command line from the console.
;
cmmnd1:	ld	sp,ccpstack	;set stack straight.
	call	crlf		;start a new line on the screen.
	call	getdsk		;get current drive.
	add	a,'a'
	call	print		;print current drive.
	ld	a,'>'
	call	print		;and add prompt.
	call	getinp		;get line from user.
;
;   process command line here.
;
cmmnd2:	ld	de,tbuff
	call	dmaset		;set standard dma address.
	call	getdsk
	ld	(cdrive),a	;set current drive.
	call	convfst		;convert name typed in.
	call	nz,synerr	;wild cards are not allowed.
	ld	a,(chgdrv)	;if a change in drives was indicated,
	or	a		;then treat this as an unknown command
	jp	nz,unknown	;which gets executed.
	call	search		;else search command table for a match.
;
;   note that an unknown command returns
; with (a) pointing to the last address
; in our table which is (unknown).
;
	ld	hl,cmdadr	;now, look thru our address table for command (a).
	ld	e,a		;set (de) to command number.
	ld	d,0
	add	hl,de
	add	hl,de		;(hl)=(cmdadr)+2*(command number).
	ld	a,(hl)		;now pick out this address.
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	(hl)		;now execute it.
;
;   cp/m command address table.
;
cmdadr:	defw	direct,erase,type,save
	defw	rename,user,unknown
;
;   halt the system. reason for this is unknown at present.
;
halt:	ld	hl,76f3h	;'di hlt' instructions.
	ld	(cbase),hl
	ld	hl,cbase
	jp	(hl)
;
;   read error while typeing a file.
;
rderror:ld	bc,rderr
	jp	pline
rderr:	defb	'read error',0
;
;   required file was not located.
;
none:	ld	bc,nofile
	jp	pline
nofile:	defb	'no file',0
;
;   decode a command of the form 'a>filename number{ filename}.
; note that a drive specifier is not allowed on the first file
; name. on return, the number is in register (a). any error
; causes 'filename?' to be printed and the command is aborted.
;
decode:	call	convfst		;convert filename.
	ld	a,(chgdrv)	;do not allow a drive to be specified.
	or	a
	jp	nz,synerr
	ld	hl,fcb+1	;convert number now.
	ld	bc,11		;(b)=sum register, (c)=max digit count.
decode1:ld	a,(hl)
	cp	' '		;a space terminates the numeral.
	jp	z,decode3
	inc	hl
	sub	'0'		;make binary from ascii.
	cp	10		;legal digit?
	jp	nc,synerr
	ld	d,a		;yes, save it in (d).
	ld	a,b		;compute (b)=(b)*10 and check for overflow.
	and	0e0h
	jp	nz,synerr
	ld	a,b
	rlca	
	rlca	
	rlca			;(a)=(b)*8
	add	a,b		;.......*9
	jp	c,synerr
	add	a,b		;.......*10
	jp	c,synerr
	add	a,d		;add in new digit now.
decode2:jp	c,synerr
	ld	b,a		;and save result.
	dec	c		;only look at 11 digits.
	jp	nz,decode1
	ret	
decode3:ld	a,(hl)		;spaces must follow (why?).
	cp	' '
	jp	nz,synerr
	inc	hl
decode4:dec	c
	jp	nz,decode3
	ld	a,b		;set (a)=the numeric value entered.
	ret	
;
;   move 3 bytes from (hl) to (de). note that there is only
; one reference to this at (a2d5h).
;
move3:	ld	b,3
;
;   move (b) bytes from (hl) to (de).
;
hl2de:	ld	a,(hl)
	ld	(de),a
	inc	hl
	inc	de
	dec	b
	jp	nz,hl2de
	ret	
;
;   compute (hl)=(tbuff)+(a)+(c) and get the byte that's here.
;
extract:ld	hl,tbuff
	add	a,c
	call	addhl
	ld	a,(hl)
	ret	
;
;  check drive specified. if it means a change, then the new
; drive will be selected. in any case, the drive byte of the
; fcb will be set to null (means use current drive).
;
dselect:xor	a		;null out first byte of fcb.
	ld	(fcb),a
	ld	a,(chgdrv)	;a drive change indicated?
	or	a
	ret	z
	dec	a		;yes, is it the same as the current drive?
	ld	hl,cdrive
	cp	(hl)
	ret	z
	jp	dsksel		;no. select it then.
;
;   check the drive selection and reset it to the previous
; drive if it was changed for the preceeding command.
;
resetdr:ld	a,(chgdrv)	;drive change indicated?
	or	a
	ret	z
	dec	a		;yes, was it a different drive?
	ld	hl,cdrive
	cp	(hl)
	ret	z
	ld	a,(cdrive)	;yes, re-select our old drive.
	jp	dsksel
;
;**************************************************************
;*
;*           D I R E C T O R Y   C O M M A N D
;*
;**************************************************************
;
direct:	call	convfst		;convert file name.
	call	dselect		;select indicated drive.
	ld	hl,fcb+1	;was any file indicated?
	ld	a,(hl)
	cp	' '
	jp	nz,direct2
	ld	b,11		;no. fill field with '?' - same as *.*.
direct1:ld	(hl),'?'
	inc	hl
	dec	b
	jp	nz,direct1
direct2:ld	e,0		;set initial cursor position.
	push	de
	call	srchfcb		;get first file name.
	call	z,none		;none found at all?
direct3:jp	z,direct9	;terminate if no more names.
	ld	a,(rtncode)	;get file's position in segment (0-3).
	rrca	
	rrca	
	rrca	
	and	60h		;(a)=position*32
	ld	c,a
	ld	a,10
	call	extract		;extract the tenth entry in fcb.
	rla			;check system file status bit.
	jp	c,direct8	;we don't list them.
	pop	de
	ld	a,e		;bump name count.
	inc	e
	push	de
	and	03h		;at end of line?
	push	af
	jp	nz,direct4
	call	crlf		;yes, end this line and start another.
	push	bc
	call	getdsk		;start line with ('a:').
	pop	bc
	add	a,'a'
	call	printb
	ld	a,':'
	call	printb
	jp	direct5
direct4:call	space		;add seperator between file names.
	ld	a,':'
	call	printb
direct5:call	space
	ld	b,1		;'extract' each file name character at a time.
direct6:ld	a,b
	call	extract
	and	7fh		;strip bit 7 (status bit).
	cp	' '		;are we at the end of the name?
	jp	nz,drect65
	pop	af		;yes, don't print spaces at the end of a line.
	push	af
	cp	3
	jp	nz,drect63
	ld	a,9		;first check for no extension.
	call	extract
	and	7fh
	cp	' '
	jp	z,direct7	;don't print spaces.
drect63:ld	a,' '		;else print them.
drect65:call	printb
	inc	b		;bump to next character psoition.
	ld	a,b
	cp	12		;end of the name?
	jp	nc,direct7
	cp	9		;nope, starting extension?
	jp	nz,direct6
	call	space		;yes, add seperating space.
	jp	direct6
direct7:pop	af		;get the next file name.
direct8:call	chkcon		;first check console, quit on anything.
	jp	nz,direct9
	call	srchnxt		;get next name.
	jp	direct3		;and continue with our list.
direct9:pop	de		;restore the stack and return to command level.
	jp	getback
;
;**************************************************************
;*
;*                E R A S E   C O M M A N D
;*
;**************************************************************
;
erase:	call	convfst		;convert file name.
	cp	11		;was '*.*' entered?
	jp	nz,erase1
	ld	bc,yesno	;yes, ask for confirmation.
	call	pline
	call	getinp
	ld	hl,inbuff+1
	dec	(hl)		;must be exactly 'y'.
	jp	nz,cmmnd1
	inc	hl
	ld	a,(hl)
	cp	'y'
	jp	nz,cmmnd1
	inc	hl
	ld	(inpoint),hl	;save input line pointer.
erase1:	call	dselect		;select desired disk.
	ld	de,fcb
	call	delete		;delete the file.
	inc	a
	call	z,none		;not there?
	jp	getback		;return to command level now.
yesno:	defb	'all (y/n)?',0
;
;**************************************************************
;*
;*            T Y P E   C O M M A N D
;*
;**************************************************************
;
type:	call	convfst		;convert file name.
	jp	nz,synerr	;wild cards not allowed.
	call	dselect		;select indicated drive.
	call	openfcb		;open the file.
	jp	z,type5		;not there?
	call	crlf		;ok, start a new line on the screen.
	ld	hl,nbytes	;initialize byte counter.
	ld	(hl),0ffh	;set to read first sector.
type1:	ld	hl,nbytes
type2:	ld	a,(hl)		;have we written the entire sector?
	cp	128
	jp	c,type3
	push	hl		;yes, read in the next one.
	call	readfcb
	pop	hl
	jp	nz,type4	;end or error?
	xor	a		;ok, clear byte counter.
	ld	(hl),a
type3:	inc	(hl)		;count this byte.
	ld	hl,tbuff	;and get the (a)th one from the buffer (tbuff).
	call	addhl
	ld	a,(hl)
	cp	cntrlz		;end of file mark?
	jp	z,getback
	call	print		;no, print it.
	call	chkcon		;check console, quit if anything ready.
	jp	nz,getback
	jp	type1
;
;   get here on an end of file or read error.
;
type4:	dec	a		;read error?
	jp	z,getback
	call	rderror		;yes, print message.
type5:	call	resetdr		;and reset proper drive
	jp	synerr		;now print file name with problem.
;
;**************************************************************
;*
;*            S A V E   C O M M A N D
;*
;**************************************************************
;
save:	call	decode		;get numeric number that follows save.
	push	af		;save number of pages to write.
	call	convfst		;convert file name.
	jp	nz,synerr	;wild cards not allowed.
	call	dselect		;select specified drive.
	ld	de,fcb		;now delete this file.
	push	de
	call	delete
	pop	de
	call	create		;and create it again.
	jp	z,save3		;can't create?
	xor	a		;clear record number byte.
	ld	(fcb+32),a
	pop	af		;convert pages to sectors.
	ld	l,a
	ld	h,0
	add	hl,hl		;(hl)=number of sectors to write.
	ld	de,tbase	;and we start from here.
save1:	ld	a,h		;done yet?
	or	l
	jp	z,save2
	dec	hl		;nope, count this and compute the start
	push	hl		;of the next 128 byte sector.
	ld	hl,128
	add	hl,de
	push	hl		;save it and set the transfer address.
	call	dmaset
	ld	de,fcb		;write out this sector now.
	call	wrtrec
	pop	de		;reset (de) to the start of the last sector.
	pop	hl		;restore sector count.
	jp	nz,save3	;write error?
	jp	save1
;
;   get here after writing all of the file.
;
save2:	ld	de,fcb		;now close the file.
	call	close
	inc	a		;did it close ok?
	jp	nz,save4
;
;   print out error message (no space).
;
save3:	ld	bc,nospace
	call	pline
save4:	call	stddma		;reset the standard dma address.
	jp	getback
nospace:defb	'no space',0
;
;**************************************************************
;*
;*           R E N A M E   C O M M A N D
;*
;**************************************************************
;
rename:	call	convfst		;convert first file name.
	jp	nz,synerr	;wild cards not allowed.
	ld	a,(chgdrv)	;remember any change in drives specified.
	push	af
	call	dselect		;and select this drive.
	call	srchfcb		;is this file present?
	jp	nz,rename6	;yes, print error message.
	ld	hl,fcb		;yes, move this name into second slot.
	ld	de,fcb+16
	ld	b,16
	call	hl2de
	ld	hl,(inpoint)	;get input pointer.
	ex	de,hl
	call	nonblank	;get next non blank character.
	cp	'='		;only allow an '=' or '_' seperator.
	jp	z,rename1
	cp	'_'
	jp	nz,rename5
rename1:ex	de,hl
	inc	hl		;ok, skip seperator.
	ld	(inpoint),hl	;save input line pointer.
	call	convfst		;convert this second file name now.
	jp	nz,rename5	;again, no wild cards.
	pop	af		;if a drive was specified, then it
	ld	b,a		;must be the same as before.
	ld	hl,chgdrv
	ld	a,(hl)
	or	a
	jp	z,rename2
	cp	b
	ld	(hl),b
	jp	nz,rename5	;they were different, error.
rename2:ld	(hl),b		;	reset as per the first file specification.
	xor	a
	ld	(fcb),a		;clear the drive byte of the fcb.
rename3:call	srchfcb		;and go look for second file.
	jp	z,rename4	;doesn't exist?
	ld	de,fcb
	call	renam		;ok, rename the file.
	jp	getback
;
;   process rename errors here.
;
rename4:call	none		;file not there.
	jp	getback
rename5:call	resetdr		;bad command format.
	jp	synerr
rename6:ld	bc,exists	;destination file already exists.
	call	pline
	jp	getback
exists:	defb	'file exists',0
;
;**************************************************************
;*
;*             U S E R   C O M M A N D
;*
;**************************************************************
;
user:	call	decode		;get numeric value following command.
	cp	16		;legal user number?
	jp	nc,synerr
	ld	e,a		;yes but is there anything else?
	ld	a,(fcb+1)
	cp	' '
	jp	z,synerr	;yes, that is not allowed.
	call	getsetuc	;ok, set user code.
	jp	getback1
;
;**************************************************************
;*
;*        T R A N S I A N T   P R O G R A M   C O M M A N D
;*
;**************************************************************
;
unknown:call	verify		;check for valid system (why?).
	ld	a,(fcb+1)	;anything to execute?
	cp	' '
	jp	nz,unkwn1
	ld	a,(chgdrv)	;nope, only a drive change?
	or	a
	jp	z,getback1	;neither???
	dec	a
	ld	(cdrive),a	;ok, store new drive.
	call	movecd		;set (tdrive) also.
	call	dsksel		;and select this drive.
	jp	getback1	;then return.
;
;   here a file name was typed. prepare to execute it.
;
unkwn1:	ld	de,fcb+9	;an extension specified?
	ld	a,(de)
	cp	' '
	jp	nz,synerr	;yes, not allowed.
unkwn2:	push	de
	call	dselect		;select specified drive.
	pop	de
	ld	hl,comfile	;set the extension to 'com'.
	call	move3
	call	openfcb		;and open this file.
	jp	z,unkwn9	;not present?
;
;   load in the program.
;
	ld	hl,tbase	;store the program starting here.
unkwn3:	push	hl
	ex	de,hl
	call	dmaset		;set transfer address.
	ld	de,fcb		;and read the next record.
	call	rdrec
	jp	nz,unkwn4	;end of file or read error?
	pop	hl		;nope, bump pointer for next sector.
	ld	de,128
	add	hl,de
	ld	de,cbase	;enough room for the whole file?
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	jp	nc,unkwn0	;no, it can't fit.
	jp	unkwn3
;
;   get here after finished reading.
;
unkwn4:	pop	hl
	dec	a		;normal end of file?
	jp	nz,unkwn0
	call	resetdr		;yes, reset previous drive.
	call	convfst		;convert the first file name that follows
	ld	hl,chgdrv	;command name.
	push	hl
	ld	a,(hl)		;set drive code in default fcb.
	ld	(fcb),a
	ld	a,16		;put second name 16 bytes later.
	call	convert		;convert second file name.
	pop	hl
	ld	a,(hl)		;and set the drive for this second file.
	ld	(fcb+16),a
	xor	a		;clear record byte in fcb.
	ld	(fcb+32),a
	ld	de,tfcb		;move it into place at(005ch).
	ld	hl,fcb
	ld	b,33
	call	hl2de
	ld	hl,inbuff+2	;now move the remainder of the input
unkwn5:	ld	a,(hl)		;line down to (0080h). look for a non blank.
	or	a		;or a null.
	jp	z,unkwn6
	cp	' '
	jp	z,unkwn6
	inc	hl
	jp	unkwn5
;
;   do the line move now. it ends in a null byte.
;
unkwn6:	ld	b,0		;keep a character count.
	ld	de,tbuff+1	;data gets put here.
unkwn7:	ld	a,(hl)		;move it now.
	ld	(de),a
	or	a
	jp	z,unkwn8
	inc	b
	inc	hl
	inc	de
	jp	unkwn7
unkwn8:	ld	a,b		;now store the character count.
	ld	(tbuff),a
	call	crlf		;clean up the screen.
	call	stddma		;set standard transfer address.
	call	setcdrv		;reset current drive.
	call	tbase		;and execute the program.
;
;   transiant programs return here (or reboot).
;
	ld	sp,batch	;set stack first off.
	call	movecd		;move current drive into place (tdrive).
	call	dsksel		;and reselect it.
	jp	cmmnd1		;back to comand mode.
;
;   get here if some error occured.
;
unkwn9:	call	resetdr		;inproper format.
	jp	synerr
unkwn0:	ld	bc,badload	;read error or won't fit.
	call	pline
	jp	getback
badload:defb	'bad load',0
comfile:defb	'com'		;command file extension.
;
;   get here to return to command level. we will reset the
; previous active drive and then either return to command
; level directly or print error message and then return.
;
getback:call	resetdr		;reset previous drive.
getback1: call	convfst		;convert first name in (fcb).
	ld	a,(fcb+1)	;if this was just a drive change request,
	sub	' '		;make sure it was valid.
	ld	hl,chgdrv
	or	(hl)
	jp	nz,synerr
	jp	cmmnd1		;ok, return to command level.
;
;   ccp stack area.
;
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
ccpstack equ	$	;end of ccp stack area.
;
;   batch (or submit) processing information storage.
;
batch:	defb	0		;batch mode flag (0=not active).
batchfcb: defb	0,'$$$     sub',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;
;   file control block setup by the ccp.
;
fcb:	defb	0,'           ',0,0,0,0,0,'           ',0,0,0,0,0
rtncode:defb	0		;status returned from bdos call.
cdrive:	defb	0		;currently active drive.
chgdrv:	defb	0		;change in drives flag (0=no change).
nbytes:	defw	0		;byte counter used by type.
;
;   room for expansion?
;
	defb	0,0,0,0,0,0,0,0,0,0
;
;   note that the following six bytes must match those at
; (pattrn1) or cp/m will halt. why?
;
pattrn2:defb	0,22,0,0,0,0	;(* serial number bytes *).
;
;**************************************************************
;*
;*                    B D O S   E N T R Y
;*
;**************************************************************
;
fbase:	jp	fbase1
;
;   bdos error table.
;
badsctr:defw	error1		;bad sector on read or write.
badslct:defw	error2		;bad disk select.
rodisk:	defw	error3		;disk is read only.
rofile:	defw	error4		;file is read only.
;
;   entry into bdos. (de) or (e) are the parameters passed. the
; function number desired is in register (c).
;
fbase1:	ex	de,hl		;save the (de) parameters.
	ld	(params),hl
	ex	de,hl
	ld	a,e		;and save register (e) in particular.
	ld	(eparam),a
	ld	hl,0
	ld	(status),hl	;clear return status.
	add	hl,sp
	ld	(usrstack),hl	;save users stack pointer.
	ld	sp,stkarea	;and set our own.
	xor	a		;clear auto select storage space.
	ld	(autoflag),a
	ld	(auto),a
	ld	hl,goback	;set return address.
	push	hl
	ld	a,c		;get function number.
	cp	nfuncts		;valid function number?
	ret	nc
	ld	c,e		;keep single register function here.
	ld	hl,functns	;now look thru the function table.
	ld	e,a
	ld	d,0		;(de)=function number.
	add	hl,de
	add	hl,de		;(hl)=(start of table)+2*(function number).
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;now (de)=address for this function.
	ld	hl,(params)	;retrieve parameters.
	ex	de,hl		;now (de) has the original parameters.
	jp	(hl)		;execute desired function.
;
;   bdos function jump table.
;
nfuncts equ	41		;number of functions in followin table.
;
functns:defw	wboot,getcon,outcon,getrdr,punch,list,dircio,getiob
	defw	setiob,prtstr,rdbuff,getcsts,getver,rstdsk,setdsk,openfil
	defw	closefil,getfst,getnxt,delfile,readseq,wrtseq,fcreate
	defw	renfile,getlog,getcrnt,putdma,getaloc,wrtprtd,getrov,setattr
	defw	getparm,getuser,rdrandom,wtrandom,filesize,setran,logoff,rtn
	defw	rtn,wtspecl
;
;   bdos error message section.
;
error1:	ld	hl,badsec	;bad sector message.
	call	prterr		;print it and get a 1 char responce.
	cp	cntrlc		;re-boot request (control-c)?
	jp	z,0		;yes.
	ret			;no, return to retry i/o function.
;
error2:	ld	hl,badsel	;bad drive selected.
	jp	error5
;
error3:	ld	hl,diskro	;disk is read only.
	jp	error5
;
error4:	ld	hl,filero	;file is read only.
;
error5:	call	prterr
	jp	0		;always reboot on these errors.
;
bdoserr:defb	'bdos err on '
bdosdrv:defb	' : $'
badsec:	defb	'bad sector$'
badsel:	defb	'select$'
filero:	defb	'file '
diskro:	defb	'r/o$'
;
;   print bdos error message.
;
prterr:	push	hl		;save second message pointer.
	call	outcrlf		;send (cr)(lf).
	ld	a,(active)	;get active drive.
	add	a,'a'		;make ascii.
	ld	(bdosdrv),a	;and put in message.
	ld	bc,bdoserr	;and print it.
	call	prtmesg
	pop	bc		;print second message line now.
	call	prtmesg
;
;   get an input character. we will check our 1 character
; buffer first. this may be set by the console status routine.
;
getchar:ld	hl,charbuf	;check character buffer.
	ld	a,(hl)		;anything present already?
	ld	(hl),0		;...either case clear it.
	or	a
	ret	nz		;yes, use it.
	jp	conin		;nope, go get a character responce.
;
;   input and echo a character.
;
getecho:call	getchar		;input a character.
	call	chkchar		;carriage control?
	ret	c		;no, a regular control char so don't echo.
	push	af		;ok, save character now.
	ld	c,a
	call	outcon		;and echo it.
	pop	af		;get character and return.
	ret	
;
;   check character in (a). set the zero flag on a carriage
; control character and the carry flag on any other control
; character.
;
chkchar:cp	cr		;check for carriage return, line feed, backspace,
	ret	z		;or a tab.
	cp	lf
	ret	z
	cp	tab
	ret	z
	cp	bs
	ret	z
	cp	' '		;other control char? set carry flag.
	ret	
;
;   check the console during output. halt on a control-s, then
; reboot on a control-c. if anything else is ready, clear the
; zero flag and return (the calling routine may want to do
; something).
;
ckconsol: ld	a,(charbuf)	;check buffer.
	or	a		;if anything, just return without checking.
	jp	nz,ckcon2
	call	const		;nothing in buffer. check console.
	and	01h		;look at bit 0.
	ret	z		;return if nothing.
	call	conin		;ok, get it.
	cp	cntrls		;if not control-s, return with zero cleared.
	jp	nz,ckcon1
	call	conin		;halt processing until another char
	cp	cntrlc		;is typed. control-c?
	jp	z,0		;yes, reboot now.
	xor	a		;no, just pretend nothing was ever ready.
	ret	
ckcon1:	ld	(charbuf),a	;save character in buffer for later processing.
ckcon2:	ld	a,1		;set (a) to non zero to mean something is ready.
	ret	
;
;   output (c) to the screen. if the printer flip-flop flag
; is set, we will send character to printer also. the console
; will be checked in the process.
;
outchar:ld	a,(outflag)	;check output flag.
	or	a		;anything and we won't generate output.
	jp	nz,outchr1
	push	bc
	call	ckconsol	;check console (we don't care whats there).
	pop	bc
	push	bc
	call	conout		;output (c) to the screen.
	pop	bc
	push	bc
	ld	a,(prtflag)	;check printer flip-flop flag.
	or	a
	call	nz,list		;print it also if non-zero.
	pop	bc
outchr1:ld	a,c		;update cursors position.
	ld	hl,curpos
	cp	del		;rubouts don't do anything here.
	ret	z
	inc	(hl)		;bump line pointer.
	cp	' '		;and return if a normal character.
	ret	nc
	dec	(hl)		;restore and check for the start of the line.
	ld	a,(hl)
	or	a
	ret	z		;ingnore control characters at the start of the line.
	ld	a,c
	cp	bs		;is it a backspace?
	jp	nz,outchr2
	dec	(hl)		;yes, backup pointer.
	ret	
outchr2:cp	lf		;is it a line feed?
	ret	nz		;ignore anything else.
	ld	(hl),0		;reset pointer to start of line.
	ret	
;
;   output (a) to the screen. if it is a control character
; (other than carriage control), use ^x format.
;
showit:	ld	a,c
	call	chkchar		;check character.
	jp	nc,outcon	;not a control, use normal output.
	push	af
	ld	c,'^'		;for a control character, preceed it with '^'.
	call	outchar
	pop	af
	or	'@'		;and then use the letter equivelant.
	ld	c,a
;
;   function to output (c) to the console device and expand tabs
; if necessary.
;
outcon:	ld	a,c
	cp	tab		;is it a tab?
	jp	nz,outchar	;use regular output.
outcon1:ld	c,' '		;yes it is, use spaces instead.
	call	outchar
	ld	a,(curpos)	;go until the cursor is at a multiple of 8

	and	07h		;position.
	jp	nz,outcon1
	ret	
;
;   echo a backspace character. erase the prevoius character
; on the screen.
;
backup:	call	backup1		;backup the screen 1 place.
	ld	c,' '		;then blank that character.
	call	conout
backup1:ld	c,bs		;then back space once more.
	jp	conout
;
;   signal a deleted line. print a '#' at the end and start
; over.
;
newline:ld	c,'#'
	call	outchar		;print this.
	call	outcrlf		;start new line.
newln1:	ld	a,(curpos)	;move the cursor to the starting position.
	ld	hl,starting
	cp	(hl)
	ret	nc		;there yet?
	ld	c,' '
	call	outchar		;nope, keep going.
	jp	newln1
;
;   output a (cr) (lf) to the console device (screen).
;
outcrlf:ld	c,cr
	call	outchar
	ld	c,lf
	jp	outchar
;
;   print message pointed to by (bc). it will end with a '$'.
;
prtmesg:ld	a,(bc)		;check for terminating character.
	cp	'$'
	ret	z
	inc	bc
	push	bc		;otherwise, bump pointer and print it.
	ld	c,a
	call	outcon
	pop	bc
	jp	prtmesg
;
;   function to execute a buffered read.
;
rdbuff:	ld	a,(curpos)	;use present location as starting one.
	ld	(starting),a
	ld	hl,(params)	;get the maximum buffer space.
	ld	c,(hl)
	inc	hl		;point to first available space.
	push	hl		;and save.
	ld	b,0		;keep a character count.
rdbuf1:	push	bc
	push	hl
rdbuf2:	call	getchar		;get the next input character.
	and	7fh		;strip bit 7.
	pop	hl		;reset registers.
	pop	bc
	cp	cr		;en of the line?
	jp	z,rdbuf17
	cp	lf
	jp	z,rdbuf17
	cp	bs		;how about a backspace?
	jp	nz,rdbuf3
	ld	a,b		;yes, but ignore at the beginning of the line.
	or	a
	jp	z,rdbuf1
	dec	b		;ok, update counter.
	ld	a,(curpos)	;if we backspace to the start of the line,
	ld	(outflag),a	;treat as a cancel (control-x).
	jp	rdbuf10
rdbuf3:	cp	del		;user typed a rubout?
	jp	nz,rdbuf4
	ld	a,b		;ignore at the start of the line.
	or	a
	jp	z,rdbuf1
	ld	a,(hl)		;ok, echo the prevoius character.
	dec	b		;and reset pointers (counters).
	dec	hl
	jp	rdbuf15
rdbuf4:	cp	cntrle		;physical end of line?
	jp	nz,rdbuf5
	push	bc		;yes, do it.
	push	hl
	call	outcrlf
	xor	a		;and update starting position.
	ld	(starting),a
	jp	rdbuf2
rdbuf5:	cp	cntrlp		;control-p?
	jp	nz,rdbuf6
	push	hl		;yes, flip the print flag filp-flop byte.
	ld	hl,prtflag
	ld	a,1		;prtflag=1-prtflag
	sub	(hl)
	ld	(hl),a
	pop	hl
	jp	rdbuf1
rdbuf6:	cp	cntrlx		;control-x (cancel)?
	jp	nz,rdbuf8
	pop	hl
rdbuf7:	ld	a,(starting)	;yes, backup the cursor to here.
	ld	hl,curpos
	cp	(hl)
	jp	nc,rdbuff	;done yet?
	dec	(hl)		;no, decrement pointer and output back up one space.
	call	backup
	jp	rdbuf7
rdbuf8:	cp	cntrlu		;cntrol-u (cancel line)?
	jp	nz,rdbuf9
	call	newline		;start a new line.
	pop	hl
	jp	rdbuff
rdbuf9:	cp	cntrlr		;control-r?
	jp	nz,rdbuf14
rdbuf10:push	bc		;yes, start a new line and retype the old one.
	call	newline
	pop	bc
	pop	hl
	push	hl
	push	bc
rdbuf11:ld	a,b		;done whole line yet?
	or	a
	jp	z,rdbuf12
	inc	hl		;nope, get next character.
	ld	c,(hl)
	dec	b		;count it.
	push	bc
	push	hl
	call	showit		;and display it.
	pop	hl
	pop	bc
	jp	rdbuf11
rdbuf12:push	hl		;done with line. if we were displaying
	ld	a,(outflag)	;then update cursor position.
	or	a
	jp	z,rdbuf2
	ld	hl,curpos	;because this line is shorter, we must
	sub	(hl)		;back up the cursor (not the screen however)
	ld	(outflag),a	;some number of positions.
rdbuf13:call	backup		;note that as long as (outflag) is non
	ld	hl,outflag	;zero, the screen will not be changed.
	dec	(hl)
	jp	nz,rdbuf13
	jp	rdbuf2		;now just get the next character.
;
;   just a normal character, put this in our buffer and echo.
;
rdbuf14:inc	hl
	ld	(hl),a		;store character.
	inc	b		;and count it.
rdbuf15:push	bc
	push	hl
	ld	c,a		;echo it now.
	call	showit
	pop	hl
	pop	bc
	ld	a,(hl)		;was it an abort request?
	cp	cntrlc		;control-c abort?
	ld	a,b
	jp	nz,rdbuf16
	cp	1		;only if at start of line.
	jp	z,0
rdbuf16:cp	c		;nope, have we filled the buffer?
	jp	c,rdbuf1
rdbuf17:pop	hl		;yes end the line and return.
	ld	(hl),b
	ld	c,cr
	jp	outchar		;output (cr) and return.
;
;   function to get a character from the console device.
;
getcon:	call	getecho		;get and echo.
	jp	setstat		;save status and return.
;
;   function to get a character from the tape reader device.
;
getrdr:	call	reader		;get a character from reader, set status and return.
	jp	setstat
;
;  function to perform direct console i/o. if (c) contains (ff)
; then this is an input request. if (c) contains (fe) then
; this is a status request. otherwise we are to output (c).
;
dircio:	ld	a,c		;test for (ff).
	inc	a
	jp	z,dirc1
	inc	a		;test for (fe).
	jp	z,const
	jp	conout		;just output (c).
dirc1:	call	const		;this is an input request.
	or	a
	jp	z,goback1	;not ready? just return (directly).
	call	conin		;yes, get character.
	jp	setstat		;set status and return.
;
;   function to return the i/o byte.
;
getiob:	ld	a,(iobyte)
	jp	setstat
;
;   function to set the i/o byte.
;
setiob:	ld	hl,iobyte
	ld	(hl),c
	ret	
;
;   function to print the character string pointed to by (de)
; on the console device. the string ends with a '$'.
;
prtstr:	ex	de,hl
	ld	c,l
	ld	b,h		;now (bc) points to it.
	jp	prtmesg
;
;   function to interigate the console device.
;
getcsts:call	ckconsol
;
;   get here to set the status and return to the cleanup
; section. then back to the user.
;
setstat:ld	(status),a
rtn:	ret	
;
;   set the status to 1 (read or write error code).
;
ioerr1:	ld	a,1
	jp	setstat
;
outflag:defb	0		;output flag (non zero means no output).
starting: defb	2		;starting position for cursor.
curpos:	defb	0		;cursor position (0=start of line).
prtflag:defb	0		;printer flag (control-p toggle). list if non zero.
charbuf:defb	0		;single input character buffer.
;
;   stack area for bdos calls.
;
usrstack: defw	0		;save users stack pointer here.
;
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
stkarea equ	$		;end of stack area.
;
userno:	defb	0		;current user number.
active:	defb	0		;currently active drive.
params:	defw	0		;save (de) parameters here on entry.
status:	defw	0		;status returned from bdos function.
;
;   select error occured, jump to error routine.
;
slcterr:ld	hl,badslct
;
;   jump to (hl) indirectly.
;
jumphl:	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;now (de) contain the desired address.
	ex	de,hl
	jp	(hl)
;
;   block move. (de) to (hl), (c) bytes total.
;
de2hl:	inc	c		;is count down to zero?
de2hl1:	dec	c
	ret	z		;yes, we are done.
	ld	a,(de)		;no, move one more byte.
	ld	(hl),a
	inc	de
	inc	hl
	jp	de2hl1		;and repeat.
;
;   select the desired drive.
;
select:	ld	a,(active)	;get active disk.
	ld	c,a
	call	seldsk		;select it.
	ld	a,h		;valid drive?
	or	l		;valid drive?
	ret	z		;return if not.
;
;   here, the bios returned the address of the parameter block
; in (hl). we will extract the necessary pointers and save them.
;
	ld	e,(hl)		;yes, get address of translation table into (de).
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(scratch1),hl	;save pointers to scratch areas.
	inc	hl
	inc	hl
	ld	(scratch2),hl	;ditto.
	inc	hl
	inc	hl
	ld	(scratch3),hl	;ditto.
	inc	hl
	inc	hl
	ex	de,hl		;now save the translation table address.
	ld	(xlate),hl
	ld	hl,dirbuf	;put the next 8 bytes here.
	ld	c,8		;they consist of the directory buffer
	call	de2hl		;pointer, parameter block pointer,
	ld	hl,(diskpb)	;check and allocation vectors.
	ex	de,hl
	ld	hl,sectors	;move parameter block into our ram.
	ld	c,15		;it is 15 bytes long.
	call	de2hl
	ld	hl,(dsksize)	;check disk size.
	ld	a,h		;more than 256 blocks on this?
	ld	hl,bigdisk
	ld	(hl),0ffh	;set to samll.
	or	a
	jp	z,select1
	ld	(hl),0		;wrong, set to large.
select1:ld	a,0ffh		;clear the zero flag.
	or	a
	ret	
;
;   routine to home the disk track head and clear pointers.
;
homedrv:call	home		;home the head.
	xor	a
	ld	hl,(scratch2)	;set our track pointer also.
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ld	hl,(scratch3)	;and our sector pointer.
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ret	
;
;   do the actual disk read and check the error return status.
;
doread:	call	read
	jp	ioret
;
;   do the actual disk write and handle any bios error.
;
dowrite:call	write
ioret:	or	a
	ret	z		;return unless an error occured.
	ld	hl,badsctr	;bad read/write on this sector.
	jp	jumphl
;
;   routine to select the track and sector that the desired
; block number falls in.
;
trksec:	ld	hl,(filepos)	;get position of last accessed file
	ld	c,2		;in directory and compute sector #.
	call	shiftr		;sector #=file-position/4.
	ld	(blknmbr),hl	;save this as the block number of interest.
	ld	(cksumtbl),hl	;what's it doing here too?
;
;   if the sector number has already been set (blknmbr), enter
; at this point.
;
trksec1:ld	hl,blknmbr
	ld	c,(hl)		;move sector number into (bc).
	inc	hl
	ld	b,(hl)
	ld	hl,(scratch3)	;get current sector number and
	ld	e,(hl)		;move this into (de).
	inc	hl
	ld	d,(hl)
	ld	hl,(scratch2)	;get current track number.
	ld	a,(hl)		;and this into (hl).
	inc	hl
	ld	h,(hl)
	ld	l,a
trksec2:ld	a,c		;is desired sector before current one?
	sub	e
	ld	a,b
	sbc	a,d
	jp	nc,trksec3
	push	hl		;yes, decrement sectors by one track.
	ld	hl,(sectors)	;get sectors per track.
	ld	a,e
	sub	l
	ld	e,a
	ld	a,d
	sbc	a,h
	ld	d,a		;now we have backed up one full track.
	pop	hl
	dec	hl		;adjust track counter.
	jp	trksec2
trksec3:push	hl		;desired sector is after current one.
	ld	hl,(sectors)	;get sectors per track.
	add	hl,de		;bump sector pointer to next track.
	jp	c,trksec4
	ld	a,c		;is desired sector now before current one?
	sub	l
	ld	a,b
	sbc	a,h
	jp	c,trksec4
	ex	de,hl		;not yes, increment track counter
	pop	hl		;and continue until it is.
	inc	hl
	jp	trksec3
;
;   here we have determined the track number that contains the
; desired sector.
;
trksec4:pop	hl		;get track number (hl).
	push	bc
	push	de
	push	hl
	ex	de,hl
	ld	hl,(offset)	;adjust for first track offset.
	add	hl,de
	ld	b,h
	ld	c,l
	call	settrk		;select this track.
	pop	de		;reset current track pointer.
	ld	hl,(scratch2)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ld	hl,(scratch3)	;reset the first sector on this track.
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	bc
	ld	a,c		;now subtract the desired one.
	sub	e		;to make it relative (1-# sectors/track).
	ld	c,a
	ld	a,b
	sbc	a,d
	ld	b,a
	ld	hl,(xlate)	;translate this sector according to this table.
	ex	de,hl
	call	sectrn		;let the bios translate it.
	ld	c,l
	ld	b,h
	jp	setsec		;and select it.
;
;   compute block number from record number (savnrec) and
; extent number (savext).
;
getblock: ld	hl,blkshft	;get logical to physical conversion.
	ld	c,(hl)		;note that this is base 2 log of ratio.
	ld	a,(savnrec)	;get record number.
getblk1:or	a		;compute (a)=(a)/2^blkshft.
	rra	
	dec	c
	jp	nz,getblk1
	ld	b,a		;save result in (b).
	ld	a,8
	sub	(hl)
	ld	c,a		;compute (c)=8-blkshft.
	ld	a,(savext)
getblk2:dec	c		;compute (a)=savext*2^(8-blkshft).
	jp	z,getblk3
	or	a
	rla	
	jp	getblk2
getblk3:add	a,b
	ret	
;
;   routine to extract the (bc) block byte from the fcb pointed
; to by (params). if this is a big-disk, then these are 16 bit
; block numbers, else they are 8 bit numbers.
; number is returned in (hl).
;
extblk:	ld	hl,(params)	;get fcb address.
	ld	de,16		;block numbers start 16 bytes into fcb.
	add	hl,de
	add	hl,bc
	ld	a,(bigdisk)	;are we using a big-disk?
	or	a
	jp	z,extblk1
	ld	l,(hl)		;no, extract an 8 bit number from the fcb.
	ld	h,0
	ret	
extblk1:add	hl,bc		;yes, extract a 16 bit number.
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl		;return in (hl).
	ret	
;
;   compute block number.
;
comblk:	call	getblock
	ld	c,a
	ld	b,0
	call	extblk
	ld	(blknmbr),hl
	ret	
;
;   check for a zero block number (unused).
;
chkblk:	ld	hl,(blknmbr)
	ld	a,l		;is it zero?
	or	h
	ret	
;
;   adjust physical block (blknmbr) and convert to logical
; sector (logsect). this is the starting sector of this block.
; the actual sector of interest is then added to this and the
; resulting sector number is stored back in (blknmbr). this
; will still have to be adjusted for the track number.
;
logical:ld	a,(blkshft)	;get log2(physical/logical sectors).
	ld	hl,(blknmbr)	;get physical sector desired.
logicl1:add	hl,hl		;compute logical sector number.
	dec	a		;note logical sectors are 128 bytes long.
	jp	nz,logicl1
	ld	(logsect),hl	;save logical sector.
	ld	a,(blkmask)	;get block mask.
	ld	c,a
	ld	a,(savnrec)	;get next sector to access.
	and	c		;extract the relative position within physical block.
	or	l		;and add it too logical sector.
	ld	l,a
	ld	(blknmbr),hl	;and store.
	ret	
;
;   set (hl) to point to extent byte in fcb.
;
setext:	ld	hl,(params)
	ld	de,12		;it is the twelth byte.
	add	hl,de
	ret	
;
;   set (hl) to point to record count byte in fcb and (de) to
; next record number byte.
;
sethlde:ld	hl,(params)
	ld	de,15		;record count byte (#15).
	add	hl,de
	ex	de,hl
	ld	hl,17		;next record number (#32).
	add	hl,de
	ret	
;
;   save current file data from fcb.
;
strdata:call	sethlde
	ld	a,(hl)		;get and store record count byte.
	ld	(savnrec),a
	ex	de,hl
	ld	a,(hl)		;get and store next record number byte.
	ld	(savnxt),a
	call	setext		;point to extent byte.
	ld	a,(extmask)	;get extent mask.
	and	(hl)
	ld	(savext),a	;and save extent here.
	ret	
;
;   set the next record to access. if (mode) is set to 2, then
; the last record byte (savnrec) has the correct number to access.
; for sequential access, (mode) will be equal to 1.
;
setnrec:call	sethlde
	ld	a,(mode)	;get sequential flag (=1).
	cp	2		;a 2 indicates that no adder is needed.
	jp	nz,stnrec1
	xor	a		;clear adder (random access?).
stnrec1:ld	c,a
	ld	a,(savnrec)	;get last record number.
	add	a,c		;increment record count.
	ld	(hl),a		;and set fcb's next record byte.
	ex	de,hl
	ld	a,(savnxt)	;get next record byte from storage.
	ld	(hl),a		;and put this into fcb as number of records used.
	ret	
;
;   shift (hl) right (c) bits.
;
shiftr:	inc	c
shiftr1:dec	c
	ret	z
	ld	a,h
	or	a
	rra	
	ld	h,a
	ld	a,l
	rra	
	ld	l,a
	jp	shiftr1
;
;   compute the check-sum for the directory buffer. return
; integer sum in (a).
;
checksum: ld	c,128		;length of buffer.
	ld	hl,(dirbuf)	;get its location.
	xor	a		;clear summation byte.
chksum1:add	a,(hl)		;and compute sum ignoring carries.
	inc	hl
	dec	c
	jp	nz,chksum1
	ret	
;
;   shift (hl) left (c) bits.
;
shiftl:	inc	c
shiftl1:dec	c
	ret	z
	add	hl,hl		;shift left 1 bit.
	jp	shiftl1
;
;   routine to set a bit in a 16 bit value contained in (bc).
; the bit set depends on the current drive selection.
;
setbit:	push	bc		;save 16 bit word.
	ld	a,(active)	;get active drive.
	ld	c,a
	ld	hl,1
	call	shiftl		;shift bit 0 into place.
	pop	bc		;now 'or' this with the original word.
	ld	a,c
	or	l
	ld	l,a		;low byte done, do high byte.
	ld	a,b
	or	h
	ld	h,a
	ret	
;
;   extract the write protect status bit for the current drive.
; the result is returned in (a), bit 0.
;
getwprt:ld	hl,(wrtprt)	;get status bytes.
	ld	a,(active)	;which drive is current?
	ld	c,a
	call	shiftr		;shift status such that bit 0 is the
	ld	a,l		;one of interest for this drive.
	and	01h		;and isolate it.
	ret	
;
;   function to write protect the current disk.
;
wrtprtd:ld	hl,wrtprt	;point to status word.
	ld	c,(hl)		;set (bc) equal to the status.
	inc	hl
	ld	b,(hl)
	call	setbit		;and set this bit according to current drive.
	ld	(wrtprt),hl	;then save.
	ld	hl,(dirsize)	;now save directory size limit.
	inc	hl		;remember the last one.
	ex	de,hl
	ld	hl,(scratch1)	;and store it here.
	ld	(hl),e		;put low byte.
	inc	hl
	ld	(hl),d		;then high byte.
	ret	
;
;   check for a read only file.
;
chkrofl:call	fcb2hl		;set (hl) to file entry in directory buffer.
ckrof1:	ld	de,9		;look at bit 7 of the ninth byte.
	add	hl,de
	ld	a,(hl)
	rla	
	ret	nc		;return if ok.
	ld	hl,rofile	;else, print error message and terminate.
	jp	jumphl
;
;   check the write protect status of the active disk.
;
chkwprt:call	getwprt
	ret	z		;return if ok.
	ld	hl,rodisk	;else print message and terminate.
	jp	jumphl
;
;   routine to set (hl) pointing to the proper entry in the
; directory buffer.
;
fcb2hl:	ld	hl,(dirbuf)	;get address of buffer.
	ld	a,(fcbpos)	;relative position of file.
;
;   routine to add (a) to (hl).
;
adda2hl:add	a,l
	ld	l,a
	ret	nc
	inc	h		;take care of any carry.
	ret	
;
;   routine to get the 's2' byte from the fcb supplied in
; the initial parameter specification.
;
gets2:	ld	hl,(params)	;get address of fcb.
	ld	de,14		;relative position of 's2'.
	add	hl,de
	ld	a,(hl)		;extract this byte.
	ret	
;
;   clear the 's2' byte in the fcb.
;
clears2:call	gets2		;this sets (hl) pointing to it.
	ld	(hl),0		;now clear it.
	ret	
;
;   set bit 7 in the 's2' byte of the fcb.
;
sets2b7:call	gets2		;get the byte.
	or	80h		;and set bit 7.
	ld	(hl),a		;then store.
	ret	
;
;   compare (filepos) with (scratch1) and set flags based on
; the difference. this checks to see if there are more file
; names in the directory. we are at (filepos) and there are
; (scratch1) of them to check.
;
morefls:ld	hl,(filepos)	;we are here.
	ex	de,hl
	ld	hl,(scratch1)	;and don't go past here.
	ld	a,e		;compute difference but don't keep.
	sub	(hl)
	inc	hl
	ld	a,d
	sbc	a,(hl)		;set carry if no more names.
	ret	
;
;   call this routine to prevent (scratch1) from being greater
; than (filepos).
;
chknmbr:call	morefls		;scratch1 too big?
	ret	c
	inc	de		;yes, reset it to (filepos).
	ld	(hl),d
	dec	hl
	ld	(hl),e
	ret	
;
;   compute (hl)=(de)-(hl)
;
subhl:	ld	a,e		;compute difference.
	sub	l
	ld	l,a		;store low byte.
	ld	a,d
	sbc	a,h
	ld	h,a		;and then high byte.
	ret	
;
;   set the directory checksum byte.
;
setdir:	ld	c,0ffh
;
;   routine to set or compare the directory checksum byte. if
; (c)=0ffh, then this will set the checksum byte. else the byte
; will be checked. if the check fails (the disk has been changed),
; then this disk will be write protected.
;
checkdir: ld	hl,(cksumtbl)
	ex	de,hl
	ld	hl,(alloc1)
	call	subhl
	ret	nc		;ok if (cksumtbl) > (alloc1), so return.
	push	bc
	call	checksum	;else compute checksum.
	ld	hl,(chkvect)	;get address of checksum table.
	ex	de,hl
	ld	hl,(cksumtbl)
	add	hl,de		;set (hl) to point to byte for this drive.
	pop	bc
	inc	c		;set or check ?
	jp	z,chkdir1
	cp	(hl)		;check them.
	ret	z		;return if they are the same.
	call	morefls		;not the same, do we care?
	ret	nc
	call	wrtprtd		;yes, mark this as write protected.
	ret	
chkdir1:ld	(hl),a		;just set the byte.
	ret	
;
;   do a write to the directory of the current disk.
;
dirwrite: call	setdir		;set checksum byte.
	call	dirdma		;set directory dma address.
	ld	c,1		;tell the bios to actually write.
	call	dowrite		;then do the write.
	jp	defdma
;
;   read from the directory.
;
dirread:call	dirdma		;set the directory dma address.
	call	doread		;and read it.
;
;   routine to set the dma address to the users choice.
;
defdma:	ld	hl,userdma	;reset the default dma address and return.
	jp	dirdma1
;
;   routine to set the dma address for directory work.
;
dirdma:	ld	hl,dirbuf
;
;   set the dma address. on entry, (hl) points to
; word containing the desired dma address.
;
dirdma1:ld	c,(hl)
	inc	hl
	ld	b,(hl)		;setup (bc) and go to the bios to set it.
	jp	setdma
;
;   move the directory buffer into user's dma space.
;
movedir:ld	hl,(dirbuf)	;buffer is located here, and
	ex	de,hl
	ld	hl,(userdma)	; put it here.
	ld	c,128		;this is its length.
	jp	de2hl		;move it now and return.
;
;   check (filepos) and set the zero flag if it equals 0ffffh.
;
ckfilpos: ld	hl,filepos
	ld	a,(hl)
	inc	hl
	cp	(hl)		;are both bytes the same?
	ret	nz
	inc	a		;yes, but are they each 0ffh?
	ret	
;
;   set location (filepos) to 0ffffh.
;
stfilpos: ld	hl,0ffffh
	ld	(filepos),hl
	ret	
;
;   move on to the next file position within the current
; directory buffer. if no more exist, set pointer to 0ffffh
; and the calling routine will check for this. enter with (c)
; equal to 0ffh to cause the checksum byte to be set, else we
; will check this disk and set write protect if checksums are
; not the same (applies only if another directory sector must
; be read).
;
nxentry:ld	hl,(dirsize)	;get directory entry size limit.
	ex	de,hl
	ld	hl,(filepos)	;get current count.
	inc	hl		;go on to the next one.
	ld	(filepos),hl
	call	subhl		;(hl)=(dirsize)-(filepos)
	jp	nc,nxent1	;is there more room left?
	jp	stfilpos	;no. set this flag and return.
nxent1:	ld	a,(filepos)	;get file position within directory.
	and	03h		;only look within this sector (only 4 entries fit).
	ld	b,5		;convert to relative position (32 bytes each).
nxent2:	add	a,a		;note that this is not efficient code.
	dec	b		;5 'add a's would be better.
	jp	nz,nxent2
	ld	(fcbpos),a	;save it as position of fcb.
	or	a
	ret	nz		;return if we are within buffer.
	push	bc
	call	trksec		;we need the next directory sector.
	call	dirread
	pop	bc
	jp	checkdir
;
;   routine to to get a bit from the disk space allocation
; map. it is returned in (a), bit position 0. on entry to here,
; set (bc) to the block number on the disk to check.
; on return, (d) will contain the original bit position for
; this block number and (hl) will point to the address for it.
;
ckbitmap: ld	a,c		;determine bit number of interest.
	and	07h		;compute (d)=(e)=(c and 7)+1.
	inc	a
	ld	e,a		;save particular bit number.
	ld	d,a
;
;   compute (bc)=(bc)/8.
;
	ld	a,c
	rrca			;now shift right 3 bits.
	rrca	
	rrca	
	and	1fh		;and clear bits 7,6,5.
	ld	c,a
	ld	a,b
	add	a,a		;now shift (b) into bits 7,6,5.
	add	a,a
	add	a,a
	add	a,a
	add	a,a
	or	c		;and add in (c).
	ld	c,a		;ok, (c) ha been completed.
	ld	a,b		;is there a better way of doing this?
	rrca	
	rrca	
	rrca	
	and	1fh
	ld	b,a		;and now (b) is completed.
;
;   use this as an offset into the disk space allocation
; table.
;
	ld	hl,(alocvect)
	add	hl,bc
	ld	a,(hl)		;now get correct byte.
ckbmap1:rlca			;get correct bit into position 0.
	dec	e
	jp	nz,ckbmap1
	ret	
;
;   set or clear the bit map such that block number (bc) will be marked
; as used. on entry, if (e)=0 then this bit will be cleared, if it equals
; 1 then it will be set (don't use anyother values).
;
stbitmap: push	de
	call	ckbitmap	;get the byte of interest.
	and	0feh		;clear the affected bit.
	pop	bc
	or	c		;and now set it acording to (c).
;
;  entry to restore the original bit position and then store
; in table. (a) contains the value, (d) contains the bit
; position (1-8), and (hl) points to the address within the
; space allocation table for this byte.
;
stbmap1:rrca			;restore original bit position.
	dec	d
	jp	nz,stbmap1
	ld	(hl),a		;and stor byte in table.
	ret	
;
;   set/clear space used bits in allocation map for this file.
; on entry, (c)=1 to set the map and (c)=0 to clear it.
;
setfile:call	fcb2hl		;get address of fcb
	ld	de,16
	add	hl,de		;get to block number bytes.
	push	bc
	ld	c,17		;check all 17 bytes (max) of table.
setfl1:	pop	de
	dec	c		;done all bytes yet?
	ret	z
	push	de
	ld	a,(bigdisk)	;check disk size for 16 bit block numbers.
	or	a
	jp	z,setfl2
	push	bc		;only 8 bit numbers. set (bc) to this one.
	push	hl
	ld	c,(hl)		;get low byte from table, always
	ld	b,0		;set high byte to zero.
	jp	setfl3
setfl2:	dec	c		;for 16 bit block numbers, adjust counter.
	push	bc
	ld	c,(hl)		;now get both the low and high bytes.
	inc	hl
	ld	b,(hl)
	push	hl
setfl3:	ld	a,c		;block used?
	or	b
	jp	z,setfl4
	ld	hl,(dsksize)	;is this block number within the
	ld	a,l		;space on the disk?
	sub	c
	ld	a,h
	sbc	a,b
	call	nc,stbitmap	;yes, set the proper bit.
setfl4:	pop	hl		;point to next block number in fcb.
	inc	hl
	pop	bc
	jp	setfl1
;
;   construct the space used allocation bit map for the active
; drive. if a file name starts with '$' and it is under the
; current user number, then (status) is set to minus 1. otherwise
; it is not set at all.
;
bitmap:	ld	hl,(dsksize)	;compute size of allocation table.
	ld	c,3
	call	shiftr		;(hl)=(hl)/8.
	inc	hl		;at lease 1 byte.
	ld	b,h
	ld	c,l		;set (bc) to the allocation table length.
;
;   initialize the bitmap for this drive. right now, the first
; two bytes are specified by the disk parameter block. however
; a patch could be entered here if it were necessary to setup
; this table in a special mannor. for example, the bios could
; determine locations of 'bad blocks' and set them as already
; 'used' in the map.
;
	ld	hl,(alocvect)	;now zero out the table now.
bitmap1:ld	(hl),0
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jp	nz,bitmap1
	ld	hl,(alloc0)	;get initial space used by directory.
	ex	de,hl
	ld	hl,(alocvect)	;and put this into map.
	ld	(hl),e
	inc	hl
	ld	(hl),d
;
;   end of initialization portion.
;
	call	homedrv		;now home the drive.
	ld	hl,(scratch1)
	ld	(hl),3		;force next directory request to read
	inc	hl		;in a sector.
	ld	(hl),0
	call	stfilpos	;clear initial file position also.
bitmap2:ld	c,0ffh		;read next file name in directory
	call	nxentry		;and set checksum byte.
	call	ckfilpos	;is there another file?
	ret	z
	call	fcb2hl		;yes, get its address.
	ld	a,0e5h
	cp	(hl)		;empty file entry?
	jp	z,bitmap2
	ld	a,(userno)	;no, correct user number?
	cp	(hl)
	jp	nz,bitmap3
	inc	hl
	ld	a,(hl)		;yes, does name start with a '$'?
	sub	'$'
	jp	nz,bitmap3
	dec	a		;yes, set atatus to minus one.
	ld	(status),a
bitmap3:ld	c,1		;now set this file's space as used in bit map.
	call	setfile
	call	chknmbr		;keep (scratch1) in bounds.
	jp	bitmap2
;
;   set the status (status) and return.
;
ststatus: ld	a,(fndstat)
	jp	setstat
;
;   check extents in (a) and (c). set the zero flag if they
; are the same. the number of 16k chunks of disk space that
; the directory extent covers is expressad is (extmask+1).
; no registers are modified.
;
samext:	push	bc
	push	af
	ld	a,(extmask)	;get extent mask and use it to
	cpl			;to compare both extent numbers.
	ld	b,a		;save resulting mask here.
	ld	a,c		;mask first extent and save in (c).
	and	b
	ld	c,a
	pop	af		;now mask second extent and compare
	and	b		;with the first one.
	sub	c
	and	1fh		;(* only check buts 0-4 *)
	pop	bc		;the zero flag is set if they are the same.
	ret			;restore (bc) and return.
;
;   search for the first occurence of a file name. on entry,
; register (c) should contain the number of bytes of the fcb
; that must match.
;
findfst:ld	a,0ffh
	ld	(fndstat),a
	ld	hl,counter	;save character count.
	ld	(hl),c
	ld	hl,(params)	;get filename to match.
	ld	(savefcb),hl	;and save.
	call	stfilpos	;clear initial file position (set to 0ffffh).
	call	homedrv		;home the drive.
;
;   entry to locate the next occurence of a filename within the
; directory. the disk is not expected to have been changed. if
; it was, then it will be write protected.
;
findnxt:ld	c,0		;write protect the disk if changed.
	call	nxentry		;get next filename entry in directory.
	call	ckfilpos	;is file position = 0ffffh?
	jp	z,fndnxt6	;yes, exit now then.
	ld	hl,(savefcb)	;set (de) pointing to filename to match.
	ex	de,hl
	ld	a,(de)
	cp	0e5h		;empty directory entry?
	jp	z,fndnxt1	;(* are we trying to reserect erased entries? *)
	push	de
	call	morefls		;more files in directory?
	pop	de
	jp	nc,fndnxt6	;no more. exit now.
fndnxt1:call	fcb2hl		;get address of this fcb in directory.
	ld	a,(counter)	;get number of bytes (characters) to check.
	ld	c,a
	ld	b,0		;initialize byte position counter.
fndnxt2:ld	a,c		;are we done with the compare?
	or	a
	jp	z,fndnxt5
	ld	a,(de)		;no, check next byte.
	cp	'?'		;don't care about this character?
	jp	z,fndnxt4
	ld	a,b		;get bytes position in fcb.
	cp	13		;don't care about the thirteenth byte either.
	jp	z,fndnxt4
	cp	12		;extent byte?
	ld	a,(de)
	jp	z,fndnxt3
	sub	(hl)		;otherwise compare characters.
	and	7fh
	jp	nz,findnxt	;not the same, check next entry.
	jp	fndnxt4		;so far so good, keep checking.
fndnxt3:push	bc		;check the extent byte here.
	ld	c,(hl)
	call	samext
	pop	bc
	jp	nz,findnxt	;not the same, look some more.
;
;   so far the names compare. bump pointers to the next byte
; and continue until all (c) characters have been checked.
;
fndnxt4:inc	de		;bump pointers.
	inc	hl
	inc	b
	dec	c		;adjust character counter.
	jp	fndnxt2
fndnxt5:ld	a,(filepos)	;return the position of this entry.
	and	03h
	ld	(status),a
	ld	hl,fndstat
	ld	a,(hl)
	rla	
	ret	nc
	xor	a
	ld	(hl),a
	ret	
;
;   filename was not found. set appropriate status.
;
fndnxt6:call	stfilpos	;set (filepos) to 0ffffh.
	ld	a,0ffh		;say not located.
	jp	setstat
;
;   erase files from the directory. only the first byte of the
; fcb will be affected. it is set to (e5).
;
erafile:call	chkwprt		;is disk write protected?
	ld	c,12		;only compare file names.
	call	findfst		;get first file name.
erafil1:call	ckfilpos	;any found?
	ret	z		;nope, we must be done.
	call	chkrofl		;is file read only?
	call	fcb2hl		;nope, get address of fcb and
	ld	(hl),0e5h	;set first byte to 'empty'.
	ld	c,0		;clear the space from the bit map.
	call	setfile
	call	dirwrite	;now write the directory sector back out.
	call	findnxt		;find the next file name.
	jp	erafil1		;and repeat process.
;
;   look through the space allocation map (bit map) for the
; next available block. start searching at block number (bc-1).
; the search procedure is to look for an empty block that is
; before the starting block. if not empty, look at a later
; block number. in this way, we return the closest empty block
; on either side of the 'target' block number. this will speed
; access on random devices. for serial devices, this should be
; changed to look in the forward direction first and then start
; at the front and search some more.
;
;   on return, (de)= block number that is empty and (hl) =0
; if no empry block was found.
;
fndspace: ld	d,b		;set (de) as the block that is checked.
	ld	e,c
;
;   look before target block. registers (bc) are used as the lower
; pointer and (de) as the upper pointer.
;
fndspa1:ld	a,c		;is block 0 specified?
	or	b
	jp	z,fndspa2
	dec	bc		;nope, check previous block.
	push	de
	push	bc
	call	ckbitmap
	rra			;is this block empty?
	jp	nc,fndspa3	;yes. use this.
;
;   note that the above logic gets the first block that it finds
; that is empty. thus a file could be written 'backward' making
; it very slow to access. this could be changed to look for the
; first empty block and then continue until the start of this
; empty space is located and then used that starting block.
; this should help speed up access to some files especially on
; a well used disk with lots of fairly small 'holes'.
;
	pop	bc		;nope, check some more.
	pop	de
;
;   now look after target block.
;
fndspa2:ld	hl,(dsksize)	;is block (de) within disk limits?
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,fndspa4
	inc	de		;yes, move on to next one.
	push	bc
	push	de
	ld	b,d
	ld	c,e
	call	ckbitmap	;check it.
	rra			;empty?
	jp	nc,fndspa3
	pop	de		;nope, continue searching.
	pop	bc
	jp	fndspa1
;
;   empty block found. set it as used and return with (hl)
; pointing to it (true?).
;
fndspa3:rla			;reset byte.
	inc	a		;and set bit 0.
	call	stbmap1		;update bit map.
	pop	hl		;set return registers.
	pop	de
	ret	
;
;   free block was not found. if (bc) is not zero, then we have
; not checked all of the disk space.
;
fndspa4:ld	a,c
	or	b
	jp	nz,fndspa1
	ld	hl,0		;set 'not found' status.
	ret	
;
;   move a complete fcb entry into the directory and write it.
;
fcbset:	ld	c,0
	ld	e,32		;length of each entry.
;
;   move (e) bytes from the fcb pointed to by (params) into
; fcb in directory starting at relative byte (c). this updated
; directory buffer is then written to the disk.
;
update:	push	de
	ld	b,0		;set (bc) to relative byte position.
	ld	hl,(params)	;get address of fcb.
	add	hl,bc		;compute starting byte.
	ex	de,hl
	call	fcb2hl		;get address of fcb to update in directory.
	pop	bc		;set (c) to number of bytes to change.
	call	de2hl
update1:call	trksec		;determine the track and sector affected.
	jp	dirwrite	;then write this sector out.
;
;   routine to change the name of all files on the disk with a
; specified name. the fcb contains the current name as the
; first 12 characters and the new name 16 bytes into the fcb.
;
chgnames: call	chkwprt		;check for a write protected disk.
	ld	c,12		;match first 12 bytes of fcb only.
	call	findfst		;get first name.
	ld	hl,(params)	;get address of fcb.
	ld	a,(hl)		;get user number.
	ld	de,16		;move over to desired name.
	add	hl,de
	ld	(hl),a		;keep same user number.
chgnam1:call	ckfilpos	;any matching file found?
	ret	z		;no, we must be done.
	call	chkrofl		;check for read only file.
	ld	c,16		;start 16 bytes into fcb.
	ld	e,12		;and update the first 12 bytes of directory.
	call	update
	call	findnxt		;get te next file name.
	jp	chgnam1		;and continue.
;
;   update a files attributes. the procedure is to search for
; every file with the same name as shown in fcb (ignoring bit 7)
; and then to update it (which includes bit 7). no other changes
; are made.
;
saveattr: ld	c,12		;match first 12 bytes.
	call	findfst		;look for first filename.
savatr1:call	ckfilpos	;was one found?
	ret	z		;nope, we must be done.
	ld	c,0		;yes, update the first 12 bytes now.
	ld	e,12
	call	update		;update filename and write directory.
	call	findnxt		;and get the next file.
	jp	savatr1		;then continue until done.
;
;  open a file (name specified in fcb).
;
openit:	ld	c,15		;compare the first 15 bytes.
	call	findfst		;get the first one in directory.
	call	ckfilpos	;any at all?
	ret	z
openit1:call	setext		;point to extent byte within users fcb.
	ld	a,(hl)		;and get it.
	push	af		;save it and address.
	push	hl
	call	fcb2hl		;point to fcb in directory.
	ex	de,hl
	ld	hl,(params)	;this is the users copy.
	ld	c,32		;move it into users space.
	push	de
	call	de2hl
	call	sets2b7		;set bit 7 in 's2' byte (unmodified).
	pop	de		;now get the extent byte from this fcb.
	ld	hl,12
	add	hl,de
	ld	c,(hl)		;into (c).
	ld	hl,15		;now get the record count byte into (b).
	add	hl,de
	ld	b,(hl)
	pop	hl		;keep the same extent as the user had originally.
	pop	af
	ld	(hl),a
	ld	a,c		;is it the same as in the directory fcb?
	cp	(hl)
	ld	a,b		;if yes, then use the same record count.
	jp	z,openit2
	ld	a,0		;if the user specified an extent greater than
	jp	c,openit2	;the one in the directory, then set record count to 0.
	ld	a,128		;otherwise set to maximum.
openit2:ld	hl,(params)	;set record count in users fcb to (a).
	ld	de,15
	add	hl,de		;compute relative position.
	ld	(hl),a		;and set the record count.
	ret	
;
;   move two bytes from (de) to (hl) if (and only if) (hl)
; point to a zero value (16 bit).
;   return with zero flag set it (de) was moved. registers (de)
; and (hl) are not changed. however (a) is.
;
moveword: ld	a,(hl)		;check for a zero word.
	inc	hl
	or	(hl)		;both bytes zero?
	dec	hl
	ret	nz		;nope, just return.
	ld	a,(de)		;yes, move two bytes from (de) into
	ld	(hl),a		;this zero space.
	inc	de
	inc	hl
	ld	a,(de)
	ld	(hl),a
	dec	de		;don't disturb these registers.
	dec	hl
	ret	
;
;   get here to close a file specified by (fcb).
;
closeit:xor	a		;clear status and file position bytes.
	ld	(status),a
	ld	(filepos),a
	ld	(filepos+1),a
	call	getwprt		;get write protect bit for this drive.
	ret	nz		;just return if it is set.
	call	gets2		;else get the 's2' byte.
	and	80h		;and look at bit 7 (file unmodified?).
	ret	nz		;just return if set.
	ld	c,15		;else look up this file in directory.
	call	findfst
	call	ckfilpos	;was it found?
	ret	z		;just return if not.
	ld	bc,16		;set (hl) pointing to records used section.
	call	fcb2hl
	add	hl,bc
	ex	de,hl
	ld	hl,(params)	;do the same for users specified fcb.
	add	hl,bc
	ld	c,16		;this many bytes are present in this extent.
closeit1: ld	a,(bigdisk)	;8 or 16 bit record numbers?
	or	a
	jp	z,closeit4
	ld	a,(hl)		;just 8 bit. get one from users fcb.
	or	a
	ld	a,(de)		;now get one from directory fcb.
	jp	nz,closeit2
	ld	(hl),a		;users byte was zero. update from directory.
closeit2: or	a
	jp	nz,closeit3
	ld	a,(hl)		;directories byte was zero, update from users fcb.
	ld	(de),a
closeit3: cp	(hl)		;if neither one of these bytes were zero,
	jp	nz,closeit7	;then close error if they are not the same.
	jp	closeit5	;ok so far, get to next byte in fcbs.
closeit4: call	moveword	;update users fcb if it is zero.
	ex	de,hl
	call	moveword	;update directories fcb if it is zero.
	ex	de,hl
	ld	a,(de)		;if these two values are no different,
	cp	(hl)		;then a close error occured.
	jp	nz,closeit7
	inc	de		;check second byte.
	inc	hl
	ld	a,(de)
	cp	(hl)
	jp	nz,closeit7
	dec	c		;remember 16 bit values.
closeit5: inc	de		;bump to next item in table.
	inc	hl
	dec	c		;there are 16 entries only.
	jp	nz,closeit1	;continue if more to do.
	ld	bc,0ffech	;backup 20 places (extent byte).
	add	hl,bc
	ex	de,hl
	add	hl,bc
	ld	a,(de)
	cp	(hl)		;directory's extent already greater than the
	jp	c,closeit6	;users extent?
	ld	(hl),a		;no, update directory extent.
	ld	bc,3		;and update the record count byte in
	add	hl,bc		;directories fcb.
	ex	de,hl
	add	hl,bc
	ld	a,(hl)		;get from user.
	ld	(de),a		;and put in directory.
closeit6: ld	a,0ffh		;set 'was open and is now closed' byte.
	ld	(closeflg),a
	jp	update1		;update the directory now.
closeit7: ld	hl,status	;set return status and then return.
	dec	(hl)
	ret	
;
;   routine to get the next empty space in the directory. it
; will then be cleared for use.
;
getempty: call	chkwprt		;make sure disk is not write protected.
	ld	hl,(params)	;save current parameters (fcb).
	push	hl
	ld	hl,emptyfcb	;use special one for empty space.
	ld	(params),hl
	ld	c,1		;search for first empty spot in directory.
	call	findfst		;(* only check first byte *)
	call	ckfilpos	;none?
	pop	hl
	ld	(params),hl	;restore original fcb address.
	ret	z		;return if no more space.
	ex	de,hl
	ld	hl,15		;point to number of records for this file.
	add	hl,de
	ld	c,17		;and clear all of this space.
	xor	a
getmt1:	ld	(hl),a
	inc	hl
	dec	c
	jp	nz,getmt1
	ld	hl,13		;clear the 's1' byte also.
	add	hl,de
	ld	(hl),a
	call	chknmbr		;keep (scratch1) within bounds.
	call	fcbset		;write out this fcb entry to directory.
	jp	sets2b7		;set 's2' byte bit 7 (unmodified at present).
;
;   routine to close the current extent and open the next one
; for reading.
;
getnext:xor	a
	ld	(closeflg),a	;clear close flag.
	call	closeit		;close this extent.
	call	ckfilpos
	ret	z		;not there???
	ld	hl,(params)	;get extent byte.
	ld	bc,12
	add	hl,bc
	ld	a,(hl)		;and increment it.
	inc	a
	and	1fh		;keep within range 0-31.
	ld	(hl),a
	jp	z,gtnext1	;overflow?
	ld	b,a		;mask extent byte.
	ld	a,(extmask)
	and	b
	ld	hl,closeflg	;check close flag (0ffh is ok).
	and	(hl)
	jp	z,gtnext2	;if zero, we must read in next extent.
	jp	gtnext3		;else, it is already in memory.
gtnext1:ld	bc,2		;point to the 's2' byte.
	add	hl,bc
	inc	(hl)		;and bump it.
	ld	a,(hl)		;too many extents?
	and	0fh
	jp	z,gtnext5	;yes, set error code.
;
;   get here to open the next extent.
;
gtnext2:ld	c,15		;set to check first 15 bytes of fcb.
	call	findfst		;find the first one.
	call	ckfilpos	;none available?
	jp	nz,gtnext3
	ld	a,(rdwrtflg)	;no extent present. can we open an empty one?
	inc	a		;0ffh means reading (so not possible).
	jp	z,gtnext5	;or an error.
	call	getempty	;we are writing, get an empty entry.
	call	ckfilpos	;none?
	jp	z,gtnext5	;error if true.
	jp	gtnext4		;else we are almost done.
gtnext3:call	openit1		;open this extent.
gtnext4:call	strdata		;move in updated data (rec #, extent #, etc.)
	xor	a		;clear status and return.
	jp	setstat
;
;   error in extending the file. too many extents were needed
; or not enough space on the disk.
;
gtnext5:call	ioerr1		;set error code, clear bit 7 of 's2'
	jp	sets2b7		;so this is not written on a close.
;
;   read a sequential file.
;
rdseq:	ld	a,1		;set sequential access mode.
	ld	(mode),a
rdseq1:	ld	a,0ffh		;don't allow reading unwritten space.
	ld	(rdwrtflg),a
	call	strdata		;put rec# and ext# into fcb.
	ld	a,(savnrec)	;get next record to read.
	ld	hl,savnxt	;get number of records in extent.
	cp	(hl)		;within this extent?
	jp	c,rdseq2
	cp	128		;no. is this extent fully used?
	jp	nz,rdseq3	;no. end-of-file.
	call	getnext		;yes, open the next one.
	xor	a		;reset next record to read.
	ld	(savnrec),a
	ld	a,(status)	;check on open, successful?
	or	a
	jp	nz,rdseq3	;no, error.
rdseq2:	call	comblk		;ok. compute block number to read.
	call	chkblk		;check it. within bounds?
	jp	z,rdseq3	;no, error.
	call	logical		;convert (blknmbr) to logical sector (128 byte).
	call	trksec1		;set the track and sector for this block #.
	call	doread		;and read it.
	jp	setnrec		;and set the next record to be accessed.
;
;   read error occured. set status and return.
;
rdseq3:	jp	ioerr1
;
;   write the next sequential record.
;
wtseq:	ld	a,1		;set sequential access mode.
	ld	(mode),a
wtseq1:	ld	a,0		;allow an addition empty extent to be opened.
	ld	(rdwrtflg),a
	call	chkwprt		;check write protect status.
	ld	hl,(params)
	call	ckrof1		;check for read only file, (hl) already set to fcb.
	call	strdata		;put updated data into fcb.
	ld	a,(savnrec)	;get record number to write.
	cp	128		;within range?
	jp	nc,ioerr1	;no, error(?).
	call	comblk		;compute block number.
	call	chkblk		;check number.
	ld	c,0		;is there one to write to?
	jp	nz,wtseq6	;yes, go do it.
	call	getblock	;get next block number within fcb to use.
	ld	(relblock),a	;and save.
	ld	bc,0		;start looking for space from the start
	or	a		;if none allocated as yet.
	jp	z,wtseq2
	ld	c,a		;extract previous block number from fcb
	dec	bc		;so we can be closest to it.
	call	extblk
	ld	b,h
	ld	c,l
wtseq2:	call	fndspace	;find the next empty block nearest number (bc).
	ld	a,l		;check for a zero number.
	or	h
	jp	nz,wtseq3
	ld	a,2		;no more space?
	jp	setstat
wtseq3:	ld	(blknmbr),hl	;save block number to access.
	ex	de,hl		;put block number into (de).
	ld	hl,(params)	;now we must update the fcb for this
	ld	bc,16		;newly allocated block.
	add	hl,bc
	ld	a,(bigdisk)	;8 or 16 bit block numbers?
	or	a
	ld	a,(relblock)	;(* update this entry *)
	jp	z,wtseq4	;zero means 16 bit ones.
	call	adda2hl		;(hl)=(hl)+(a)
	ld	(hl),e		;store new block number.
	jp	wtseq5
wtseq4:	ld	c,a		;compute spot in this 16 bit table.
	ld	b,0
	add	hl,bc
	add	hl,bc
	ld	(hl),e		;stuff block number (de) there.
	inc	hl
	ld	(hl),d
wtseq5:	ld	c,2		;set (c) to indicate writing to un-used disk space.
wtseq6:	ld	a,(status)	;are we ok so far?
	or	a
	ret	nz
	push	bc		;yes, save write flag for bios (register c).
	call	logical		;convert (blknmbr) over to loical sectors.
	ld	a,(mode)	;get access mode flag (1=sequential,
	dec	a		;0=random, 2=special?).
	dec	a
	jp	nz,wtseq9
;
;   special random i/o from function #40. maybe for m/pm, but the
; current block, if it has not been written to, will be zeroed
; out and then written (reason?).
;
	pop	bc
	push	bc
	ld	a,c		;get write status flag (2=writing unused space).
	dec	a
	dec	a
	jp	nz,wtseq9
	push	hl
	ld	hl,(dirbuf)	;zero out the directory buffer.
	ld	d,a		;note that (a) is zero here.
wtseq7:	ld	(hl),a
	inc	hl
	inc	d		;do 128 bytes.
	jp	p,wtseq7
	call	dirdma		;tell the bios the dma address for directory access.
	ld	hl,(logsect)	;get sector that starts current block.
	ld	c,2		;set 'writing to unused space' flag.
wtseq8:	ld	(blknmbr),hl	;save sector to write.
	push	bc
	call	trksec1		;determine its track and sector numbers.
	pop	bc
	call	dowrite		;now write out 128 bytes of zeros.
	ld	hl,(blknmbr)	;get sector number.
	ld	c,0		;set normal write flag.
	ld	a,(blkmask)	;determine if we have written the entire
	ld	b,a		;physical block.
	and	l
	cp	b
	inc	hl		;prepare for the next one.
	jp	nz,wtseq8	;continue until (blkmask+1) sectors written.
	pop	hl		;reset next sector number.
	ld	(blknmbr),hl
	call	defdma		;and reset dma address.
;
;   normal disk write. set the desired track and sector then
; do the actual write.
;
wtseq9:	call	trksec1		;determine track and sector for this write.
	pop	bc		;get write status flag.
	push	bc
	call	dowrite		;and write this out.
	pop	bc
	ld	a,(savnrec)	;get number of records in file.
	ld	hl,savnxt	;get last record written.
	cp	(hl)
	jp	c,wtseq10
	ld	(hl),a		;we have to update record count.
	inc	(hl)
	ld	c,2
;
;*   this area has been patched to correct disk update problem
;* when using blocking and de-blocking in the bios.
;
wtseq10:nop			;was 'dcr c'
	nop			;was 'dcr c'
	ld	hl,0		;was 'jnz wtseq99'
;
; *   end of patch.
;
	push	af
	call	gets2		;set 'extent written to' flag.
	and	7fh		;(* clear bit 7 *)
	ld	(hl),a
	pop	af		;get record count for this extent.
wtseq99:cp	127		;is it full?
	jp	nz,wtseq12
	ld	a,(mode)	;yes, are we in sequential mode?
	cp	1
	jp	nz,wtseq12
	call	setnrec		;yes, set next record number.
	call	getnext		;and get next empty space in directory.
	ld	hl,status	;ok?
	ld	a,(hl)
	or	a
	jp	nz,wtseq11
	dec	a		;yes, set record count to -1.
	ld	(savnrec),a
wtseq11:ld	(hl),0		;clear status.
wtseq12:jp	setnrec		;set next record to access.
;
;   for random i/o, set the fcb for the desired record number
; based on the 'r0,r1,r2' bytes. these bytes in the fcb are
; used as follows:
;
;       fcb+35            fcb+34            fcb+33
;  |     'r-2'      |      'r-1'      |      'r-0'     |
;  |7             0 | 7             0 | 7             0|
;  |0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0|
;  |    overflow   | | extra |  extent   |   record #  |
;  | ______________| |_extent|__number___|_____________|
;                     also 's2'
;
;   on entry, register (c) contains 0ffh if this is a read
; and thus we can not access unwritten disk space. otherwise,
; another extent will be opened (for writing) if required.
;
position: xor	a		;set random i/o flag.
	ld	(mode),a
;
;   special entry (function #40). m/pm ?
;
positn1:push	bc		;save read/write flag.
	ld	hl,(params)	;get address of fcb.
	ex	de,hl
	ld	hl,33		;now get byte 'r0'.
	add	hl,de
	ld	a,(hl)
	and	7fh		;keep bits 0-6 for the record number to access.
	push	af
	ld	a,(hl)		;now get bit 7 of 'r0' and bits 0-3 of 'r1'.
	rla	
	inc	hl
	ld	a,(hl)
	rla	
	and	1fh		;and save this in bits 0-4 of (c).
	ld	c,a		;this is the extent byte.
	ld	a,(hl)		;now get the extra extent byte.
	rra	
	rra	
	rra	
	rra	
	and	0fh
	ld	b,a		;and save it in (b).
	pop	af		;get record number back to (a).
	inc	hl		;check overflow byte 'r2'.
	ld	l,(hl)
	inc	l
	dec	l
	ld	l,6		;prepare for error.
	jp	nz,positn5	;out of disk space error.
	ld	hl,32		;store record number into fcb.
	add	hl,de
	ld	(hl),a
	ld	hl,12		;and now check the extent byte.
	add	hl,de
	ld	a,c
	sub	(hl)		;same extent as before?
	jp	nz,positn2
	ld	hl,14		;yes, check extra extent byte 's2' also.
	add	hl,de
	ld	a,b
	sub	(hl)
	and	7fh
	jp	z,positn3	;same, we are almost done then.
;
;  get here when another extent is required.
;
positn2:push	bc
	push	de
	call	closeit		;close current extent.
	pop	de
	pop	bc
	ld	l,3		;prepare for error.
	ld	a,(status)
	inc	a
	jp	z,positn4	;close error.
	ld	hl,12		;put desired extent into fcb now.
	add	hl,de
	ld	(hl),c
	ld	hl,14		;and store extra extent byte 's2'.
	add	hl,de
	ld	(hl),b
	call	openit		;try and get this extent.
	ld	a,(status)	;was it there?
	inc	a
	jp	nz,positn3
	pop	bc		;no. can we create a new one (writing?).
	push	bc
	ld	l,4		;prepare for error.
	inc	c
	jp	z,positn4	;nope, reading unwritten space error.
	call	getempty	;yes we can, try to find space.
	ld	l,5		;prepare for error.
	ld	a,(status)
	inc	a
	jp	z,positn4	;out of space?
;
;   normal return location. clear error code and return.
;
positn3:pop	bc		;restore stack.
	xor	a		;and clear error code byte.
	jp	setstat
;
;   error. set the 's2' byte to indicate this (why?).
;
positn4:push	hl
	call	gets2
	ld	(hl),0c0h
	pop	hl
;
;   return with error code (presently in l).
;
positn5:pop	bc
	ld	a,l		;get error code.
	ld	(status),a
	jp	sets2b7
;
;   read a random record.
;
readran:ld	c,0ffh		;set 'read' status.
	call	position	;position the file to proper record.
	call	z,rdseq1	;and read it as usual (if no errors).
	ret	
;
;   write to a random record.
;
writeran: ld	c,0		;set 'writing' flag.
	call	position	;position the file to proper record.
	call	z,wtseq1	;and write as usual (if no errors).
	ret	
;
;   compute the random record number. enter with (hl) pointing
; to a fcb an (de) contains a relative location of a record
; number. on exit, (c) contains the 'r0' byte, (b) the 'r1'
; byte, and (a) the 'r2' byte.
;
;   on return, the zero flag is set if the record is within
; bounds. otherwise, an overflow occured.
;
comprand: ex	de,hl		;save fcb pointer in (de).
	add	hl,de		;compute relative position of record #.
	ld	c,(hl)		;get record number into (bc).
	ld	b,0
	ld	hl,12		;now get extent.
	add	hl,de
	ld	a,(hl)		;compute (bc)=(record #)+(extent)*128.
	rrca			;move lower bit into bit 7.
	and	80h		;and ignore all other bits.
	add	a,c		;add to our record number.
	ld	c,a
	ld	a,0		;take care of any carry.
	adc	a,b
	ld	b,a
	ld	a,(hl)		;now get the upper bits of extent into
	rrca			;bit positions 0-3.
	and	0fh		;and ignore all others.
	add	a,b		;add this in to 'r1' byte.
	ld	b,a
	ld	hl,14		;get the 's2' byte (extra extent).
	add	hl,de
	ld	a,(hl)
	add	a,a		;and shift it left 4 bits (bits 4-7).
	add	a,a
	add	a,a
	add	a,a
	push	af		;save carry flag (bit 0 of flag byte).
	add	a,b		;now add extra extent into 'r1'.
	ld	b,a
	push	af		;and save carry (overflow byte 'r2').
	pop	hl		;bit 0 of (l) is the overflow indicator.
	ld	a,l
	pop	hl		;and same for first carry flag.
	or	l		;either one of these set?
	and	01h		;only check the carry flags.
	ret	
;
;   routine to setup the fcb (bytes 'r0', 'r1', 'r2') to
; reflect the last record used for a random (or other) file.
; this reads the directory and looks at all extents computing
; the largerst record number for each and keeping the maximum
; value only. then 'r0', 'r1', and 'r2' will reflect this
; maximum record number. this is used to compute the space used
; by a random file.
;
ransize:ld	c,12		;look thru directory for first entry with
	call	findfst		;this name.
	ld	hl,(params)	;zero out the 'r0, r1, r2' bytes.
	ld	de,33
	add	hl,de
	push	hl
	ld	(hl),d		;note that (d)=0.
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(hl),d
ransiz1:call	ckfilpos	;is there an extent to process?
	jp	z,ransiz3	;no, we are done.
	call	fcb2hl		;set (hl) pointing to proper fcb in dir.
	ld	de,15		;point to last record in extent.
	call	comprand	;and compute random parameters.
	pop	hl
	push	hl		;now check these values against those
	ld	e,a		;already in fcb.
	ld	a,c		;the carry flag will be set if those
	sub	(hl)		;in the fcb represent a larger size than
	inc	hl		;this extent does.
	ld	a,b
	sbc	a,(hl)
	inc	hl
	ld	a,e
	sbc	a,(hl)
	jp	c,ransiz2
	ld	(hl),e		;we found a larger (in size) extent.
	dec	hl		;stuff these values into fcb.
	ld	(hl),b
	dec	hl
	ld	(hl),c
ransiz2:call	findnxt		;now get the next extent.
	jp	ransiz1		;continue til all done.
ransiz3:pop	hl		;we are done, restore the stack and
	ret			;return.
;
;   function to return the random record position of a given
; file which has been read in sequential mode up to now.
;
setran:	ld	hl,(params)	;point to fcb.
	ld	de,32		;and to last used record.
	call	comprand	;compute random position.
	ld	hl,33		;now stuff these values into fcb.
	add	hl,de
	ld	(hl),c		;move 'r0'.
	inc	hl
	ld	(hl),b		;and 'r1'.
	inc	hl
	ld	(hl),a		;and lastly 'r2'.
	ret	
;
;   this routine select the drive specified in (active) and
; update the login vector and bitmap table if this drive was
; not already active.
;
logindrv: ld	hl,(login)	;get the login vector.
	ld	a,(active)	;get the default drive.
	ld	c,a
	call	shiftr		;position active bit for this drive
	push	hl		;into bit 0.
	ex	de,hl
	call	select		;select this drive.
	pop	hl
	call	z,slcterr	;valid drive?
	ld	a,l		;is this a newly activated drive?
	rra	
	ret	c
	ld	hl,(login)	;yes, update the login vector.
	ld	c,l
	ld	b,h
	call	setbit
	ld	(login),hl	;and save.
	jp	bitmap		;now update the bitmap.
;
;   function to set the active disk number.
;
setdsk:	ld	a,(eparam)	;get parameter passed and see if this
	ld	hl,active	;represents a change in drives.
	cp	(hl)
	ret	z
	ld	(hl),a		;yes it does, log it in.
	jp	logindrv
;
;   this is the 'auto disk select' routine. the firsst byte
; of the fcb is examined for a drive specification. if non
; zero then the drive will be selected and loged in.
;
autosel:ld	a,0ffh		;say 'auto-select activated'.
	ld	(auto),a
	ld	hl,(params)	;get drive specified.
	ld	a,(hl)
	and	1fh		;look at lower 5 bits.
	dec	a		;adjust for (1=a, 2=b) etc.
	ld	(eparam),a	;and save for the select routine.
	cp	1eh		;check for 'no change' condition.
	jp	nc,autosl1	;yes, don't change.
	ld	a,(active)	;we must change, save currently active
	ld	(olddrv),a	;drive.
	ld	a,(hl)		;and save first byte of fcb also.
	ld	(autoflag),a	;this must be non-zero.
	and	0e0h		;whats this for (bits 6,7 are used for
	ld	(hl),a		;something)?
	call	setdsk		;select and log in this drive.
autosl1:ld	a,(userno)	;move user number into fcb.
	ld	hl,(params)	;(* upper half of first byte *)
	or	(hl)
	ld	(hl),a
	ret			;and return (all done).
;
;   function to return the current cp/m version number.
;
getver:	ld	a,022h		;version 2.2
	jp	setstat
;
;   function to reset the disk system.
;
rstdsk:	ld	hl,0		;clear write protect status and log
	ld	(wrtprt),hl	;in vector.
	ld	(login),hl
	xor	a		;select drive 'a'.
	ld	(active),a
	ld	hl,tbuff	;setup default dma address.
	ld	(userdma),hl
	call	defdma
	jp	logindrv	;now log in drive 'a'.
;
;   function to open a specified file.
;
openfil:call	clears2		;clear 's2' byte.
	call	autosel		;select proper disk.
	jp	openit		;and open the file.
;
;   function to close a specified file.
;
closefil: call	autosel		;select proper disk.
	jp	closeit		;and close the file.
;
;   function to return the first occurence of a specified file
; name. if the first byte of the fcb is '?' then the name will
; not be checked (get the first entry no matter what).
;
getfst:	ld	c,0		;prepare for special search.
	ex	de,hl
	ld	a,(hl)		;is first byte a '?'?
	cp	'?'
	jp	z,getfst1	;yes, just get very first entry (zero length match).
	call	setext		;get the extension byte from fcb.
	ld	a,(hl)		;is it '?'? if yes, then we want
	cp	'?'		;an entry with a specific 's2' byte.
	call	nz,clears2	;otherwise, look for a zero 's2' byte.
	call	autosel		;select proper drive.
	ld	c,15		;compare bytes 0-14 in fcb (12&13 excluded).
getfst1:call	findfst		;find an entry and then move it into
	jp	movedir		;the users dma space.
;
;   function to return the next occurence of a file name.
;
getnxt:	ld	hl,(savefcb)	;restore pointers. note that no
	ld	(params),hl	;other dbos calls are allowed.
	call	autosel		;no error will be returned, but the
	call	findnxt		;results will be wrong.
	jp	movedir
;
;   function to delete a file by name.
;
delfile:call	autosel		;select proper drive.
	call	erafile		;erase the file.
	jp	ststatus	;set status and return.
;
;   function to execute a sequential read of the specified
; record number.
;
readseq:call	autosel		;select proper drive then read.
	jp	rdseq
;
;   function to write the net sequential record.
;
wrtseq:	call	autosel		;select proper drive then write.
	jp	wtseq
;
;   create a file function.
;
fcreate:call	clears2		;clear the 's2' byte on all creates.
	call	autosel		;select proper drive and get the next
	jp	getempty	;empty directory space.
;
;   function to rename a file.
;
renfile:call	autosel		;select proper drive and then switch
	call	chgnames	;file names.
	jp	ststatus
;
;   function to return the login vector.
;
getlog:	ld	hl,(login)
	jp	getprm1
;
;   function to return the current disk assignment.
;
getcrnt:ld	a,(active)
	jp	setstat
;
;   function to set the dma address.
;
putdma:	ex	de,hl
	ld	(userdma),hl	;save in our space and then get to
	jp	defdma		;the bios with this also.
;
;   function to return the allocation vector.
;
getaloc:ld	hl,(alocvect)
	jp	getprm1
;
;   function to return the read-only status vector.
;
getrov:	ld	hl,(wrtprt)
	jp	getprm1
;
;   function to set the file attributes (read-only, system).
;
setattr:call	autosel		;select proper drive then save attributes.
	call	saveattr
	jp	ststatus
;
;   function to return the address of the disk parameter block
; for the current drive.
;
getparm:ld	hl,(diskpb)
getprm1:ld	(status),hl
	ret	
;
;   function to get or set the user number. if (e) was (ff)
; then this is a request to return the current user number.
; else set the user number from (e).
;
getuser:ld	a,(eparam)	;get parameter.
	cp	0ffh		;get user number?
	jp	nz,setuser
	ld	a,(userno)	;yes, just do it.
	jp	setstat
setuser:and	1fh		;no, we should set it instead. keep low
	ld	(userno),a	;bits (0-4) only.
	ret	
;
;   function to read a random record from a file.
;
rdrandom: call	autosel		;select proper drive and read.
	jp	readran
;
;   function to compute the file size for random files.
;
wtrandom: call	autosel		;select proper drive and write.
	jp	writeran
;
;   function to compute the size of a random file.
;
filesize: call	autosel		;select proper drive and check file length
	jp	ransize
;
;   function #37. this allows a program to log off any drives.
; on entry, set (de) to contain a word with bits set for those
; drives that are to be logged off. the log-in vector and the
; write protect vector will be updated. this must be a m/pm
; special function.
;
logoff:	ld	hl,(params)	;get drives to log off.
	ld	a,l		;for each bit that is set, we want
	cpl			;to clear that bit in (login)
	ld	e,a		;and (wrtprt).
	ld	a,h
	cpl	
	ld	hl,(login)	;reset the login vector.
	and	h
	ld	d,a
	ld	a,l
	and	e
	ld	e,a
	ld	hl,(wrtprt)
	ex	de,hl
	ld	(login),hl	;and save.
	ld	a,l		;now do the write protect vector.
	and	e
	ld	l,a
	ld	a,h
	and	d
	ld	h,a
	ld	(wrtprt),hl	;and save. all done.
	ret	
;
;   get here to return to the user.
;
goback:	ld	a,(auto)	;was auto select activated?
	or	a
	jp	z,goback1
	ld	hl,(params)	;yes, but was a change made?
	ld	(hl),0		;(* reset first byte of fcb *)
	ld	a,(autoflag)
	or	a
	jp	z,goback1
	ld	(hl),a		;yes, reset first byte properly.
	ld	a,(olddrv)	;and get the old drive and select it.
	ld	(eparam),a
	call	setdsk
goback1:ld	hl,(usrstack)	;reset the users stack pointer.
	ld	sp,hl
	ld	hl,(status)	;get return status.
	ld	a,l		;force version 1.4 compatability.
	ld	b,h
	ret			;and go back to user.
;
;   function #40. this is a special entry to do random i/o.
; for the case where we are writing to unused disk space, this
; space will be zeroed out first. this must be a m/pm special
; purpose function, because why would any normal program even
; care about the previous contents of a sector about to be
; written over.
;
wtspecl:call	autosel		;select proper drive.
	ld	a,2		;use special write mode.
	ld	(mode),a
	ld	c,0		;set write indicator.
	call	positn1		;position the file.
	call	z,wtseq1	;and write (if no errors).
	ret	
;
;**************************************************************
;*
;*     bdos data storage pool.
;*
;**************************************************************
;
emptyfcb: defb	0e5h		;empty directory segment indicator.
wrtprt:	defw	0		;write protect status for all 16 drives.
login:	defw	0		;drive active word (1 bit per drive).
userdma:defw	080h		;user's dma address (defaults to 80h).
;
;   scratch areas from parameter block.
;
scratch1: defw	0		;relative position within dir segment for file (0-3).
scratch2: defw	0		;last selected track number.
scratch3: defw	0		;last selected sector number.
;
;   disk storage areas from parameter block.
;
dirbuf:	defw	0		;address of directory buffer to use.
diskpb:	defw	0		;contains address of disk parameter block.
chkvect:defw	0		;address of check vector.
alocvect: defw	0		;address of allocation vector (bit map).
;
;   parameter block returned from the bios.
;
sectors:defw	0		;sectors per track from bios.
blkshft:defb	0		;block shift.
blkmask:defb	0		;block mask.
extmask:defb	0		;extent mask.
dsksize:defw	0		;disk size from bios (number of blocks-1).
dirsize:defw	0		;directory size.
alloc0:	defw	0		;storage for first bytes of bit map (dir space used).
alloc1:	defw	0
offset:	defw	0		;first usable track number.
xlate:	defw	0		;sector translation table address.
;
;
closeflg: defb	0		;close flag (=0ffh is extent written ok).
rdwrtflg: defb	0		;read/write flag (0ffh=read, 0=write).
fndstat:defb	0		;filename found status (0=found first entry).
mode:	defb	0		;i/o mode select (0=random, 1=sequential, 2=special random).
eparam:	defb	0		;storage for register (e) on entry to bdos.
relblock: defb	0		;relative position within fcb of block number written.
counter:defb	0		;byte counter for directory name searches.
savefcb:defw	0,0		;save space for address of fcb (for directory searches).
bigdisk:defb	0		;if =0 then disk is > 256 blocks long.
auto:	defb	0		;if non-zero, then auto select activated.
olddrv:	defb	0		;on auto select, storage for previous drive.
autoflag: defb	0		;if non-zero, then auto select changed drives.
savnxt:	defb	0		;storage for next record number to access.
savext:	defb	0		;storage for extent number of file.
savnrec:defw	0		;storage for number of records in file.
blknmbr:defw	0		;block number (physical sector) used within a file or logical sect
logsect:defw	0		;starting logical (128 byte) sector of block (physical sector).
fcbpos:	defb	0		;relative position within buffer for fcb of file of interest.
filepos:defw	0		;files position within directory (0 to max entries -1).
;
;   disk directory buffer checksum bytes. one for each of the
; 16 possible drives.
;
cksumtbl: defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;
;   extra space ?
;
	defb	0,0,0,0
	
#include "bios.asm"
;
;*
;******************   E N D   O F   C P / M   *****************
;*

