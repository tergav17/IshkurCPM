;
;**************************************************************
;*
;*           D I G I T A L   R E S E A R C H   C C P
;*
;*      This is the default CCP supplied by CP/M, with a
;*      few select modifications.
;*
;*         Custom CCP prompt by NabuNetwork.com
;*
;**************************************************************
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

cbase:	jp	command		;execute command processor (ccp).
	jp	clearbuf	;entry to empty input buffer before starting ccp.

;
;   standard cp/m ccp input buffer. format is (max length),
; (actual length), (char #1), (char #2), (char #3), etc.
;
inbuff:	defb	127		;length of input buffer.
	defb	0		;current length of contents.
	defb	'INIT '
	defb	255,0,0,0
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
	jr	printb
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
getinp0:dec	a
	ld	(batchfcb+32),a
	ld	de,batchfcb
	push	af
	call	rdrec		;read last record.
	pop	de
	jp	nz,getinp1	;quit on end of file.
	ld	hl,tbuff	;data was read into buffer here.
	xor	a		;skip if entry has nothing in it
	cp	(hl)
	ld	a,d
	jr	z,getinp0

;   move this record into input buffer.
;
	ld	de,inbuff+1
	ld	b,128		;all 128 characters may be used.
	push	hl		;save tbuff
	call	hl2de		;(hl) to (de), (b) bytes.
	pop	hl		;zero out first in tbuff
	ld	(hl),0
	ld	hl,batchfcb+32
	dec	(hl)		;decrement the record count.
	ld	de,batchfcb	;close the batch file now.
	push	de
	call	wrtrec		;write out record
	pop	de
	call	close
	jr	z,getinp1	;quit on an error.
	ld	a,(cdrive)	;re-select previous drive if need be.
	or	a
	call	nz,dsksel	;don't do needless selects.
;
;   print line just read on console.
;
	ld	hl,inbuff+2
	call	pline2
	call	chkcon		;check console, quit on a key.
	jr	z,getinp2	;jump if no key is pressed.
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
	jr	z,getinp4
	ld	a,(hl)		;convert to upper case.
	call	upper
	ld	(hl),a
	dec	b		;adjust character count.
	jr	getinp3
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
verify:	ld	de,pattrn1+2	;these are the serial number bytes.
	ld	hl,pattrn2+2	;ditto, but how could they be different?
	ld	b,1		;6 bytes each.
verify1:ld	a,(de)
	cp	(hl)
	;jp	nz,halt		;jump to halt routine.
	nop
	nop
	nop
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
	sbc	a,'A'-1		;might be a drive name, convert to binary.
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
cmdtbl:	defb	'DIR '
	defb	'ERA '
	defb	'TYPE'
	defb	'SAVE'
	defb	'REN '
	defb	'USER'
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
	;ld	(batch),a	;clear batch mode flag.
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
;   Big thanks to NabuNetwork.com for the modified prompt!
;
cmmnd1:	ld	sp,ccpstack	;set stack straight.
	call	crlf		;start a new line on the screen.
	call	getdsk		;get current drive.
	add	a,'A'
	call	print		;print current drive.
	call	getusr		;get current user.
	add	a,'0'
	call	printdc		;print current user.
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
	add	a,'A'
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
	cp	'Y'
	jp	nz,cmmnd1
	inc	hl
	ld	(inpoint),hl	;save input line pointer.
erase1:	call	dselect		;select desired disk.
	ld	de,fcb
	call	delete		;delete the file.
	inc	a
	call	z,none		;not there?
	jp	getback		;return to command level now.
yesno:	defb	'All (Y/N)?',0
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
	jr	nz,rename5	;they were different, error.
rename2:ld	(hl),b		;	reset as per the first file specification.
	xor	a
	ld	(fcb),a		;clear the drive byte of the fcb.
rename3:call	srchfcb		;and go look for second file.
	jr	z,rename4	;doesn't exist?
	ld	de,fcb
	call	renam		;ok, rename the file.
	jp	getback
;
;   process rename errors here.
;
rename4:call	none		;file not there.
	jp	getback
rename5:call	resetdr		;bad command format.
synerrt:jp	synerr
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
	jr	nc,synerrt
	ld	e,a		;yes but is there anything else?
	ld	a,(fcb+1)
	cp	' '
	jr	z,synerrt	;yes, that is not allowed.
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
	jr	nz,unkwn1
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
	jr	nz,synerrt	;yes, not allowed.
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
	jr	nz,unkwn4	;end of file or read error?
	pop	hl		;nope, bump pointer for next sector.
	ld	de,128
	add	hl,de
	ld	de,cbase	;enough room for the whole file?
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	jr	nc,unkwn0	;no, it can't fit.
	jr	unkwn3
;
;   get here after finished reading.
;
unkwn4:	pop	hl
	dec	a		;normal end of file?
	jr	nz,unkwn0
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
	jr	z,unkwn6
	cp	' '
	jr	z,unkwn6
	inc	hl
	jr	unkwn5
;
;   do the line move now. it ends in a null byte.
;
unkwn6:	ld	b,0		;keep a character count.
	ld	de,tbuff+1	;data gets put here.
unkwn7:	ld	a,(hl)		;move it now.
	ld	(de),a
	or	a
	jr	z,unkwn8
	inc	b
	inc	hl
	inc	de
	jr	unkwn7
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
	jr	getback
badload:defb	'Bad load',0
comfile:defb	'COM'		;command file extension.
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
	
; Small routine to print a decimal 0-19
printdc:cp	':'
	jp	c,print
	sub	10
	push	af
	ld	a,'1'
	call	print
	pop	af
	jr	printdc
;
;   ccp stack area.
;
	defb	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
ccpstack equ	$	;end of ccp stack area.
;
;   batch (or submit) processing information storage.
;
batch:	defb	0		;batch mode flag (0=not active).
batchfcb: defb	0,'$$$     SUB',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;
;   file control block setup by the ccp.
;
fcb:	defb	0,'           ',0,0,0,0,0,'           ',0,0,0,0,0
rtncode:defb	0		;status returned from bdos call.
cdrive:	defb	0		;currently active drive.
chgdrv:	defb	0		;change in drives flag (0=no change).
nbytes:	defw	0		;byte counter used by type.