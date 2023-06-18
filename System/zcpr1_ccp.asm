;**************************************************************
;*
;*         Z C P R 1   C O M M A N D   P R O C E S S O R
;*
;*          Adapted to work with Ishkur by snhirsch
;*
;**************************************************************

iobyte	equ	3		;i/o definition byte.
tdrive	equ	4		;current drive name and user number.
UDFLAG  equ     4
entry	equ	5		;entry point for the cp/m bdos.
BDOS    equ     5
tfcb	equ	5ch		;default file control block.
TFCB    equ     5ch
TBUFF   equ     80h
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

;================================================================

;	.Z80
;	TITLE	'NZCPR V 1.6Z OF 01/07/84'
;  This is ZCPR Version 1.6 changed to Zilog mnemonics and put in a
;form suitable for the Microsoft M80 assembler. Note that the file uses
;the PHASE option to create the memory offset. The COM file should be 
;created using L80 with the /P:100 switch option. The COM file can be
;loaded into the sysgen program using the methods described in the ZCPR
;documentation.
;		MMA - Murray Arnow
;
;  CP/M Z80 Command Processor Replacement (CPR) Version 1.6 in
; the NZCPR line.
;
;	CCPZ CREATED AND CUSTOMIZED FOR ARIES-II BY RLC
;	ZCPR VERSION 1.0 CREATED FROM CCPZ VERSION 4.0 BY RLC IN
;		A COORDINATED EFFORT WITH CCP-GROUP
;
;	ZCPR is a group effort by CCP-GROUP, whose active membership involved
; in this project consists of the following:
;		RLC - Richard Conn
;		RGF - Ron Fowler
;		KBP - Keith Peterson
;		FJW - Frank Wancho
;	The following individuals also provided a contribution:
;		SBB - Steve Bogolub
;
;  Since RLC has decided that ZCPR V1.0 is the last official version
; sanctioned by the CCPZ group, changes beyond that point are being
; called by consensus of a group of new changers "NZCPR Vx.x". The
; following individuals have put in their code or opinions:
;
;		SBB - Steve Bogolub
;		PST - Paul Traina
;		HLB - Howard Booker
;		CAF - Chuck Forsberg
;		RAF - Bob Fischer
;		BB  - Ben Bronson
;		PRG - Paul Grupp
;		PJH - Paul Homchick
;		HEW - Hal Walchli
;
;   In an attempt to maintain a link to the past, changes between the
; current version of NZCPR are provided as both a difference file
; between NZCPR's (NZ14-16.DIF) and as a difference between the current
; version and the "official" ZCPR V1.0 (NZCPR-16.DIF).  These changes
; are made and supported by individuals in contact with each other through
; the Hyde Park RCPM in Chicago. Make comments or complaints there, to
; SBB or PST or anyone else interested.
;
;   The most obvious differences between NZCPR and ZCPR are the security
; features, controlled by additional conditional assembly flags. Such
; features restrict access to ZCPR intrinsic commands, add additional
; levels of .COM file searching, and prevent access to higher drives
; or user levels, with either internal or external password control of
; these features. Less obvious differences involve code optimization to
; gain space, and some minor bug fixes in the TYPE command.
;
;******** Structure Notes ********
;
;	This CPR is divided into a number of major sections.  The following
; is an outline of these sections and the names of the major routines
; located therein.
;
; Section	Function/Routines
; -------	-----------------
;
;   --		Opening Comments, Equates, and Macro Definitions
;
;    0		JMP Table into CPR
;
;    1		Buffers
;
;    2		CPR Starting Modules
;			CPR1	CPR	RESTRT	RSTCPR	RCPRNL
;			PRNNF	CMDTBL
;
;    3		Utilities
;			CRLF	CONOUT	CONIN	LCOUT	LSTOUT
;			READF	READ	BDOSB	PRINTC	PRINT
;			GETDRV	DEFDMA	DMASET	RESET	BDOSJP
;			LOGIN	OPENF	OPEN	GRBDOS	CLOSE
;			SEARF	SEAR1	SEARN	SUBKIL	DELETE
;			RESETUSR GETUSR	SETUSR	PAGER	UCASE
;			NOECHO
;
;     4		CPR Utilities
;			SETUD	SETU0D	REDBUF	CNVBUF	CMDSER
;			BREAK	USRNUM	ERROR	SDELM	ADVAN
;			SBLANK	ADDAH	NUMBER	NUMERR	HEXNUM
;			DIRPTR	SLOGIN	DLOGIN	COMLOG	SCANER
;
;     5		CPR-Resident Commands and Functions
;     5A		DIR	DIRPR	FILLQ
;     5B		ERA
;     5C		LIST
;     5D		TYPE
;     5E		SAVE
;     5F		REN
;     5G		USER
;     5H		DFU
;     5I		JUMP
;     5J		GO
;     5K		COM	CALLPROG	ERRLOG	ERRJMP
;     5L		GET	MEMLOAD	PRNLE
;     5M		PASS	NORM
;
;
FALSE	EQU	0
TRUE	EQU	0FFh
;
;  CUSTOMIZATION EQUATES
;
;  The following equates may be used to customize this CPR for the user's
;    system and integration technique.  The following constants are provided:
;
;    REL - TRUE if integration is to be done via MOVCPM
;        - FALSE if integration is to be done via DDT and SYSGEN
;
;    SECURE -  TRUE to conditionally disable potentially-harmful
;	       commands (GO, ERA, SAVE, REN, DFU, GET, JUMP). Under
;	       SECURE, if WHEEL contains RESTRCT, do not accept those
;	       commands, and search for COM files under current user
;	       then user "DEFUSR" only. If WHEEL does not contain
;	       RESTRCT (presumably from passworded change), allow
;	       all commands, and search current user, then last user
;	       set by DFU (originally "RESUSR"), then user "DEFUSR"
;	       for COM files, giving access with password to an
;	       additional level of COM files.
;
;	       (Note: WHEEL must point to a safe place in memory that
;		won't be overlayed)
;
;	If you have chosen a SECURE system,  all resident commands may be
; activated by entering:  PASS <password> <cr>  Where <password> is a sequence
; of characters placed at PASSID (if INPASS is true, otherwise, see
; documentation in PST's PASS.ASM).  If the password is incorrect. the system
; will come back with PASS? as if it was looking for a COM file.
;	NORM is the reverse of PASS, it will disable the WHEEL mode.
;
;    INPASS -  If in the SECURE mode, you wish to use a program similar
;	       to PST's PASS.ASM, set this false, otherwise, ZCPR will
;	       handle the PASSword coding with a built in command.
;
;    DRUSER -  Set this EQU false if you wish to disable RAF's neat hack
;	       that allows you the type B: 7 to move to drive B: user area
;	       seven.  This also removes the USER command.  Basically, set
;	       this equate false if you want to use USERPW or some other pgm.
;
;    RAS    -  Remote-Access System; setting this equate to TRUE disables
;	       certain CPR commands that are considered harmful in a Remote-
;	       Access environment; use under Remote-Access Systems (RBBS) for
;	       security purposes.  Note: SECURE is the direct enemy of RAS,
;	       DON'T define both equates or you will be VERY sorry.
;	       The advantage SECURE has over RAS is that by saying a magic
;	       word, all of the normal commands pop into existance.
;
;    MAXDRIV - Maximum legal drive number stored in this location.
;	       (0 means only A:, etc.)  0000H disables this feature.
;	       The value MAXDR is stuffed into MAXDRIV at cold boot,
;	       and presumably will be changed later by a passworded
;	       program if desired.
;
;	       (This code is in addition to BIOS checks. It's needed here
;	       because X: can hang if X: is off line in some BIOS
;	       implementations. Personally, I think CAF and others should fix
;	       their BIOS instead. Mine works right...SBB).
;
;    USRMAX -  Maximum legal user # + 1 stored in this location. 0000H
;	       disables this feature, and uses the value of MAXUSR+1 instead.
;
;    BASE - Base Address of user's CP/M system (normally 0 for DR version)
;           This equate allows easy modification by non-standard CP/M (eg,H89)
;
;    CPRLOC - Base Page Address of CPR; this value can be obtained by running
;	      the BDOSLOC program on your system, or by setting the
;	      MSIZE and BIOSEX equates to the system memory size in
;	      K-bytes and the "extra" memory required by your BIOS
;	      in K-bytes. BIOSEX is zero if your BIOS is normal size,
;	      and can be negative if your BIOS is in PROM or in
;	      non-contiguous memory.
;
;    EPRMPT - Set TRUE to be prompted "OK?" after seeing what files will
;	      be erased. No, this is NOT for individual file prompting,
;	      it is just to confirm deletion of all selected files at once.
;
;  Various individuals keep trying to yank out the TYPE, LIST, and DIR
; commands, either to use the space for other options or just because
; they prefer replacement COM files. To these individuals, I (SBB) say
; keep your paws off these commands. For compatibility with the stock
; CCP, intrinsic DIR and TYPE commands are required. And many users in
; MY neighborhood find it more convenient to use the intrinsic LIST
; command than to have a LIST/PRINT program on every disk. If you want
; to call a transient program by an intrinsic, then CHANGE THE INTRINSIC
; NAME IN THE TABLE. Even setting the name to blanks is fine to get
; rid of it. The point is, don't remove features others may want, just
; because you disagree, then throw it back in our laps. For those who
; simply MUST be rid of these commands, the following symbols control
; generation of the code in a CLEAN ACCEPTABLE fashion that allows
; others to have these features:
;
;    CPRTYP -	Set to TRUE to generate code for intrinsic TYPE command.
;
;    WSTYPE -	Set to TRUE to generate an extra three lines of code
;		to correctly interpret the WordStar (tm) internal
;		end of line hyphen for display, which is the ASCII
;		NEWLINE code (1FH) and normally non-printing or
;		troublemaking -- thanks to PJH for this one. CPRTYP
;		must be TRUE, or this symbol will be ignored.
;
;    CPRLST -	Set to TRUE to generate code for intrinsic LIST command.
;		Since almost all of the LIST code is common to the
;		TYPE code, CPRTYP must be set TRUE as well, or this
;		symbol will be ignored.
;
;    CPRDIR -	Set to TRUE to generate code for intrinsic DIR command.
;		Note that unlike the various directory programs, a
;		restricted DIR command here allows displaying the names
;		of SYS file ONLY, so many RCPM operators WANT this code.
;
;  Remember, you only get a total of 2048 (0800H) bytes of space for
; ALL of the generated code, or many other areas of your system
; generation will be affected. For example, to be fully SECURE, you
; would set SECURE to TRUE, and define MAXDRIV and USRMAX, and maybe
; use the internal password by setting INPASS to TRUE (external is
; MUCH recommended for easier modification). Those options absolutely
; generate too much code unless either CPRTYP or CPRDIR or both are
; set FALSE. A system with SECURE set to FALSE is right on the edge,
; and requires a give and take on options to fit, i.e. you can have
; MAXDRIV and USRMAX with DIR and TYPE if you leave out LIST and
; querying on ERASE, and so on.
;
;***************************************************************************
;** Be careful when playing with different combinations of these equates. **
;** You might not have enough memory to some combinations.  Check this    **
;** if you have problems, if they still persist, gripe to me (PST).       **
;***************************************************************************
;
;REL	EQU	TRUE		;SET TO TRUE FOR MOVCPM INTEGRATION
;
;BASE	EQU	0		;BASE OF CP/M SYSTEM (SET FOR STANDARD CP/M)
;
;; 	IF	REL
;; CPRLOC	EQU	0		;MOVCPM IMAGE
;; 	ELSE
;; ;
;; ; If REL is FALSE, the value of CPRLOC may be set in one
;; ; of two ways.  The first way is to set MSIZE and BIOSEX
;; ; as described above using the following three lines:
;; ;
;; ;MSIZE	EQU	56		;SIZE OF MEM IN K-BYTES
;; ;BIOSEX	EQU	2		;EXTRA # K-BYTES IN BIOS
;; ;CPRLOC	EQU	3400H+(MSIZE-20-BIOSEX)*1024	;CPR ORIGIN
;; ;
;; ; The second way is to obtain the origin of your current
;; ; CPR using BDSLOC or its equivalent, then merely set CPRLOC
;; ; to that value as in the following line:
;; ;
;; CPRLOC	EQU	0C400H		;FILL IN WITH BDOSLOC SUPPLIED VALUE
;; ;
;; ; Note that you should only use one method or the other.
;; ; Do NOT define CPRLOC twice!
;; ;
;; ; The following gives the required offset to load the CPR into the
;; ; CP/M SYSGEN Image through DDT (the Roffset command); Note that this
;; ; value conforms with the standard value presented in the CP/M reference
;; ; manuals, but it may not necessarily conform with the location of the
;; ; CCP in YOUR CP/M system; several systems (Morrow Designs, P&T, Heath
;; ; Org-0 to name a few) have the CCP located at a non-standard address in
;; ; the SYSGEN Image
;; ;
;; CPRR	EQU	0E00H-CPRLOC	;DDT LOAD OFFSET FOR APPLE SOFTCARD 56K
;; ;CPRR	EQU	0980H-CPRLOC	;DDT LOAD OFFSET
;; ;CPRR	EQU	1600H-CPRLOC	;DDT LOAD OFFSET FOR COMPUPRO DISK-1
;; ;CPRR	EQU	1100H-CPRLOC	;DDT LOAD OFFSET FOR MORROW DESIGNS
;; 	ENDIF
;
RAS	EQU	FALSE		;SET TO TRUE IF CPR IS FOR A REMOTE-ACCESS
				; SYSTEM AND YOU DON'T WANT TO RUN SECURE
				; (FOO...)
;
USRMAX	EQU	0000H		;LOCATION OF BYTE IN MEMORY CONTAINING
				; NUMBER OF HIGHEST ALLOWABLE USER CODE + 1
				; THIS VALUE IS SET BY CPR ON COLD BOOT,
				; AND PRESUMABLY CONTROLLED AFTER THAT
				; BY A PASSWORD PROGRAM. IF USRMAX=0, THEN
				; MAXUSR BELOW IS USED FOR CHECKING ONLY.
				; 03FH IS RECOMMENDED IF USED  ***
MAXUSR	EQU	19		;MAX ALLOWED USER NUMBER, THIS + 1 IS STUFFED
				; INTO USRMAX ON COLD BOOT, OR USED DIRECTLY
				; IF USRMAX=0
;
MAXDRIV	EQU	0000H		;LOCATION THAT HAS MAX LEGAL DRIVE #
				;SET IT TO ZERO TO DISABLE THIS CHECK
				;03DH IS RECOMMENDED IF USED ***
MAXDR	EQU	1		;MAX DRIVE # TO SET INTO MAXDRIV ON COLD BOOT
;
SECURE	EQU	FALSE		;SET TRUE FOR SECURE ENVIRONMENT...
;
DEFUSR	EQU	0		;DEFAULT USER FOR UNRESTRICTED COM FILES
;
	IF	SECURE
WHEEL	EQU	3EH		;SET TO "RESTRCT" FOR LIMITED ACCESS
RESTRCT EQU	0		;WHEN (WHEEL)==RESTRCT, LIMIT COMMANDS
RESUSR	EQU	15		;CHECK HERE FOR RESTRICTED ACCESS COM FILES
				; (LIKE PIP) UNTIL CHANGED BY DFU OR WARM BOOT
	ENDIF			;SECURE
;
INPASS	EQU	FALSE		;SET TRUE IF RUNNING SECURE AND NOT PASS.COM
;
DRUSER	EQU	TRUE		;TRUE TO ALLOW USER COMMAND AND DRIVE/USER HACK
;
EPRMPT	EQU	FALSE		;TRUE TO PROMPT BEFORE ERASING ALL FILES
;
CPRTYP	EQU	TRUE		;TRUE TO GENERATE TYPE CODE
WSTYPE	EQU	TRUE		;TRUE TO GENERATE WORDSTAR HYPHEN CHECK (CPRTYP
				; MUST BE TRUE TOO)
CPRLST	EQU	TRUE		;TRUE TO GENERATE LIST CODE (CPRTYP MUST BETRUE TOO)
CPRDIR	EQU	TRUE		;TRUE TO GENERATE DIR CODE
;
;  ***  Note to Apple Softcard Users  ***
;
;  In their infinite (?) wisdom (???), Microsoft decided that the way to
; get a two-column directory display instead of four-column (narrow 40-col
; screen, remember) was to have their BIOS poke CCP every time it was
; loaded, if there was no terminal interface card in I/O slot 3.
; Naturally, that will turn into a random poke on any non-standard
; CCP, like this one.  The best way to get this CPR up on the Apple is to
; load it into CPM56.COM, at location 0E00H in the image.  The BIOS code
; that pokes the CPR can also be modified at that time.  The poke is done
; by "STA 0C8B2H", found at 24FEH in the CPM56 image.  To keep this
; feature, change the 0C8B2H address in that instruction by hand to
; the value generated for the symbol TWOPOK in the DIR routine.  If
; you have assembled out the DIR code by setting CPRDIR to FALSE, then
; disable this feature by changing the "STA" to "LDA", i.e. set the
; contents of location 24FEH from 32H to 3AH. If you wish to force
; a two-column display in all cases, set the TWOCOL switch below to a
; value of TRUE, and disable the poke.
;
TWOCOL	EQU	FALSE		;TRUE IF TWO COL DIR INSTEAD OF FOUR
;
; The following is presented as an option, but is not generally user-customiz-
; able.  A basic design choice had to be made in the design of ZCPR concerning
; the execution of SUBMIT files.  The original CCP had a problem in this sense
; in that it ALWAYS looked for the SUBMIT file from drive A: and the SUBMIT
; program itself (SUBMIT.COM) would place the $$$.SUB file on the currently
; logged-in drive, so when the user was logged into B: and he issued a SUBMIT
; command, the $$$.SUB was placed on B: and did not execute because the CCP
; looked for it on A: and never found it.
;
;	After much debate it was decided to have ZCPR perform the same type of
; function as CCP (look for the $$$.SUB file on A:), but the problem with
; SUBMIT.COM still exists.  Hence, RGF designed SuperSUB and RLC took his
; SuperSUB and designed SUB from it; both programs are set up to allow the
; selection at assembly time of creating the $$$.SUB on the logged-in drive
; or on drive A:.
;
;	A final definition of the Indirect Command File ($$$.SUB or SUBMIT
; File) is presented as follows:
;
;		"An Indirect Command File is one which contains
;		 a series of commands exactly as they would be
;		 entered from a CP/M Console.  The SUBMIT Command
;		 (or SUB Command) reads this files and transforms
;		 it for processing by the ZCPR (the $$$.SUB File).
;		 ZCPR will then execute the commands indicated
;		 EXACTLY as if they were typed at the Console."
;
;	Hence, to permit this to happen, the $$$.SUB file must always
; be present on a specific drive, and A: is the choice for said drive.
; With this facility engaged as such, Indirect Command Files like:
;
;		DIR
;		A:
;		DIR
;
; can be executed, even though the currently logged-in drive is changed
; during execution.  If the $$$.SUB file was present on the currently
; logged-in drive, the above series of commands would not work since the
; ZCPR would be looking for $$$.SUB on the logged-in drive, and switching
; logged-in drives without moving the $$$.SUB file as well would cause
; processing to abort.
;
SUBA	EQU	TRUE 		;Set to TRUE to have $$$.SUB always on A:
				;Set to FALSE to have $$$.SUB on the
				; logged-in drive
;
;   The following flag enables extended processing for user-program supplied
; command lines.  This is for Command Level 3 of ZCPR.  Under the current
; ZCPR philosophy, three command levels exist:
;
;	(1) that command issued by the user from his console at the '>' prompt
;	(2) that command issued by a $$$.SUB file at the '$' prompt
;	(3) that command issued by a user program by placing the command into
;	    CIBUFF and setting the character count in CBUFF
;
;   Setting CLEVEL3 to TRUE enables extended processing of the third level of
; ZCPR command.  All the user program need do is to store the command line and
; set the character count; ZCPR will initialize the pointers properly, store
; the ending zero properly, and capitalize the command line for processing.
; Once the command line is properly stored, the user executes the command line
; by reentering the ZCPR through CPRLOC [NOTE:  The C register MUST contain
; a valid User/Disk Flag (see location 4) at this time.]
;
CLEVEL3	EQU	TRUE		;ENABLE COMMAND LEVEL 3 PROCESSING
;
;
;*** TERMINAL AND 'TYPE' CUSTOMIZATION EQUATES
;
NLINES	EQU	24		;NUMBER OF LINES ON CRT SCREEN
WIDE	EQU	TRUE		;TRUE IF WIDE DIR DISPLAY
FENCE	EQU	'|'		;SEP CHAR BETWEEN DIR FILES
;
PGDFLT	EQU	FALSE 		;SET TO FALSE TO DISABLE PAGING BY DEFAULT
PGDFLG	EQU	'P'		;FOR TYPE COMMAND: PAGE OR NOT (DEP ON PGDFLT)
				;  THIS FLAG REVERSES THE DEFAULT EFFECT
;
SYSFLG	EQU	'A' 		;FOR DIR COMMAND: LIST $SYS AND $DIR
;
SOFLG	EQU	'S'		;FOR DIR COMMAND: LIST $SYS FILES ONLY
;
SUPRES	EQU	FALSE		;SUPRESSES USER # REPORT FOR USER 0
;
SPRMPT	EQU	'$'		;CPR PROMPT INDICATING SUBMIT COMMAND
CPRMPT	EQU	'>'		;CPR PROMPT INDICATING USER COMMAND
;
NUMBASE	EQU	'H'		;CHARACTER USED TO SWITCH FROM DEFAULT
				; NUMBER BASE
;
SECTFLG	EQU	'S'		;OPTION CHAR FOR SAVE COMMAND TO SAVE SECTORS
;
; END OF CUSTOMIZATION SECTION
;
CR	EQU	0DH
LF	EQU	0AH
TAB	EQU	09H
FFEED	EQU	0CH
BEL	EQU	07H
;
;; WBOOT	EQU	BASE+0000H		;CP/M WARM BOOT ADDRESS
;; UDFLAG	EQU	BASE+0004H		;USER NUM IN HIGH NYBBLE, DISK IN LOW
;; BDOS	EQU	BASE+0005H		;BDOS FUNCTION CALL ENTRY PT
;; TFCB	EQU	BASE+005CH		;DEFAULT FCB BUFFER
;; TBUFF	EQU	BASE+0080H		;DEFAULT DISK I/O BUFFER
;; TPA	EQU	BASE+0100H		;BASE OF TPA

TPA    EQU     100H

;
;**** Section 0 ****
;
;	ORG	0100H
;	.PHASE	CPRLOC
;
;  ENTRY POINTS INTO ZCPR
;
;    If the ZCPR is entered at location CPRLOC (at the JMP to CPR), then
; the default command in CIBUFF will be processed.  If the ZCPR is entered
; at location CPRLOC+3 (at the JMP to CPR1), then the default command in
; CIBUFF will NOT be processed.
;
;    NOTE:  Entry into ZCPR in this way is permitted under this version,
; but in order for this to work, CIBUFF and CBUFF MUST be initialized properly
; AND the C register MUST contain a valid User/Disk Flag (see Location 4: the
; most significant nybble contains the User Number and the least significant
; nybble contains the Disk Number).
;
;    Some user programs (such as SYNONYM3) attempt to use the default
; command facility.  Under the original CCP, it was necessary to initialize
; the pointer after the reserved space for the command buffer to point to
; the first byte of the command buffer.  Under current versions, this is
; no longer the case.  The CIBPTR (Command Input Buffer PoinTeR) is located
; to be compatible with such programs (provided they determine the buffer
; length from the byte at MBUFF [CPRLOC + 6]), but under ZCPR this is
; no longer necessary, since this buffer pointer is automatically
; initialized in all cases.
;
cbase:  
ENTRY:
	JP	CPR		; Process potential default command, and set
				; USRMAX to MAXUSR default
	JP	CPR1		; Do NOT process potential default command
;	
;**** Section 1 ****
; BUFFERS ET AL
;
; INPUT COMMAND LINE AND DEFAULT COMMAND
;
;   The command line to be executed is stored here.  This command line
; is generated in one of three ways:
;
;	(1) by the user entering it through the BDOS READLN function at
;	    the du> prompt [user input from keyboard]
;	(2) by the SUBMIT File Facility placing it there from a $$$.SUB
;	    file
;	(3) by an external program or user placing the required command
;	    into this buffer
;
;   In all cases, the command line is placed into the buffer starting at
; CIBUFF.  This command line is terminated by the last character (NOT Carriage
; Return), and a character count of all characters in the command line
; up to and including the last character is placed into location CBUFF
; (immediately before the command line at CIBUFF).  The placed command line
; is then parsed, interpreted, and the indicated command is executed.
; If CLEVEL3 is permitted, a terminating zero is placed after the command
; (otherwise the user program has to place this zero) and the CIBPTR is
; properly initialized (otherwise the user program has to init this ptr).
; If the command is placed by a user program, entering at CPRLOC is enough
; to have the command processed.  Again, under the current ZCPR, it is not
; necessary to store the pointer to CIBUFF in CIBPTR; ZCPR will do this for
; the calling program if CLEVEL3 is made TRUE.
;
;   WARNING:  The command line must NOT exceed BUFLEN characters in length.
; For user programs which load this command, the value of BUFLEN can be
; obtained by examining the byte at MBUFF (CPRLOC + 6).
;
inbuff: 
BUFLEN	EQU	80		;MAXIMUM BUFFER LENGTH
MBUFF:
	DEFB	BUFLEN		;MAXIMUM BUFFER LENGTH
CBUFF:
	DEFB	0		;NUMBER OF VALID CHARS IN COMMAND LINE

CIBUFF:
 	DEFM	'INIT '
        DEFB    255
        DEFM    '        ';DEFAULT (COLD BOOT) COMMAND
;
;  The copyright notice from Digital Research is genned into the
; stock CCP at this location. It should be maintained in ZCPR,
; since Digital Research grants permission for ZCPR to exist.
;
	DEFM	'  COPYRIGHT (C) 1979, DIGITAL RESEARCH  '
CIBUF:
	DEFB	0		;COMMAND STRING TERMINATOR
	DEFM	'NZCPR V 1.6 of'
	DEFM	' 08/03/82 '	;ZCPR ID FOR DISK DUMP
 	DEFS	BUFLEN-($-CIBUFF)+1	;TOTAL IS 'BUFLEN' BYTES
;
CIBPTR:
	DEFW	CIBUFF		;POINTER TO COMMAND INPUT BUFFER
CIPTR:
	DEFW	CIBUF		;POINTER TO CURR COMMAND FOR
				; ERROR REPORTING
;
	DEFS	26		;STACK AREA
STACK	EQU	$		;TOP OF STACK
;
; FILE TYPE FOR COMMAND
;
COMMSG:
	DEFM	'COM'
;
; SUBMIT FILE CONTROL BLOCK
;
SUBFCB:
	IF	SUBA		;IF $$$.SUB ON A:
	DEFB	1		;DISK NAME SET TO DEFAULT TO DRIVE A:
;	ENDIF
;
;	IF	NOT SUBA	;IF $$$.SUB ON CURRENT DRIVE
        ELSE
	DEFB	0		;DISK NAME SET TO DEFAULT TO CURRENT DRIVE
	ENDIF
;
	DEFM	'$$$'		;FILE NAME
	DEFM	'     '
	DEFM	'SUB'		;FILE TYPE
	DEFB	0		;EXTENT NUMBER
	DEFB	0		;S1
SUBFS2:
	DEFS	1		;S2
SUBFRC:
	DEFS	1		;RECORD COUNT
	DEFS	16		;DISK GROUP MAP
SUBFCR:
	DEFS	1		;CURRENT RECORD NUMBER
; COMMAND FILE CONTROL BLOCK
;
FCBDN:
	DEFS	1		;DISK NAME
FCBFN:
	DEFS	8		;FILE NAME
FCBFT:
	DEFS	3		;FILE TYPE
	DEFS	1		;EXTENT NUMBER
	DEFS	2		;S1 AND S2
	DEFS	1		;RECORD COUNT
FCBDM:
	DEFS	16		;DISK GROUP MAP
FCBCR:
	DEFS	1		;CURRENT RECORD NUMBER
;
; OTHER BUFFERS
;
PAGCNT:
	DEFB	NLINES-2	;LINES LEFT ON PAGE
CHRCNT:
	DEFB	0		;CHAR COUNT FOR TYPE
QMCNT:
	DEFB	0		;QUESTION MARK COUNT FOR FCB TOKEN SCANNER
;
;
;**** Section 2 ****
; CPR STARTING POINTS.  NOTE THAT SOME CP/M IMPLEMENTATIONS
; REQUIRE THE COLD START ADDRESS TO BE IN THE STARTING PAGE
; OF THE CPR, FOR DYNAMIC CCP LOADING.  CMDTBL WAS MOVED FOR
; THIS REASON.
;
; SET USRMAX AND/OR MAXDRIV TO DEFAULT VALUES ON COLD BOOT
; IF REQUIRED. NOTE THAT SOME BIOS IMPLEMENTATIONS WILL END
; UP HERE INSTEAD OF AT THE WARM BOOT, DEFEATING PASSWORDING
; OF THESE OPTIONS. RECOMMEND SUCH A BIOS BE FIXED.
;
	IF	USRMAX OR MAXDRIV
CPR:
	IF	USRMAX
	LD	A,MAXUSR+1	;SET USRMAX ON COLD BOOT
	LD	(USRMAX),A
	ENDIF			;USRMAX
;
	IF	MAXDRIV
	LD	A,MAXDR		;SET MAXDRIV ON COLD BOOT
	LD	(MAXDRIV),A
	ENDIF			;MAXDRIV
;
	JR	CPR2		; THEN PROCEED
	ENDIF			;USRMAX OR MAXDRIV
;
; START CPR AND DON'T PROCESS DEFAULT COMMAND STORED
;
CPR1:
	XOR	A		;SET NO DEFAULT COMMAND
	LD	(CBUFF),A
;
; START CPR AND POSSIBLY PROCESS DEFAULT COMMAND
;
; NOTE ON MODIFICATION BY RGF: BDOS RETURNS 0FFH IN
; ACCUMULATOR WHENEVER IT LOGS IN A DIRECTORY, IF ANY
; FILE NAME CONTAINS A '$' IN IT.  THIS IS NOW USED AS
; A CLUE TO DETERMINE WHETHER OR NOT TO DO A SEARCH
; FOR SUBMIT FILE, IN ORDER TO ELIMINATE WASTEFUL SEARCHES.
;
	IF	USRMAX OR MAXDRIV
CPR2:
	ELSE
CPR:
	ENDIF			;USRMAX OR MAXDRIV
;
	LD	SP,STACK	;RESET STACK
	PUSH	BC
	LD	A,C		;C=USER/DISK NUMBER (SEE LOC 4)
	RRA			;EXTRACT USER NUMBER
	RRA
	RRA
	RRA
	AND	0FH
	LD	E,A		;SET USER NUMBER
	CALL	SETUSR
	CALL	RESET		;RESET DISK SYSTEM
	;LD	(RNGSUB),A	;SAVE SUBMIT CLUE FROM DRIVE A:
	NOP
	NOP
	NOP
	POP	BC
	LD	A,C		;C=USER/DISK NUMBER (SEE LOC 4)
	AND	0FH		;EXTRACT DEFAULT DISK DRIVE
	LD	(TDRIVE),A	;SET IT
	JR	Z,NOLOG		;SKIP IF 0...ALREADY LOGGED
	CALL	LOGIN		;LOG IN DEFAULT DISK
;
	IF	SUBA	;IF $$$.SUB IS ON CURRENT DRIVE
        ELSE
	LD	(RNGSUB),A	;BDOS '$' CLUE
	ENDIF
;
NOLOG:
	LD	DE,SUBFCB	;CHECK FOR $$$.SUB ON CURRENT DISK
batch:  EQU     $+1
RNGSUB:	EQU	$+1		;POINTER FOR IN-THE-CODE MODIFICATION
        LD	A,0	        ;2ND BYTE (IMMEDIATE ARG) IS THE RNGSUB FLAG
	OR	A		;SET FLAGS ON CLUE
	CPL			;PREPARE FOR COMING 'CPL'
	CALL	NZ,SEAR1
	CPL			;0FFH IS RETURNED IF NO $$$.SUB, SO COMPLEMENT
	LD	(RNGSUB),A	;SET FLAG (0=NO $$$.SUB)
	LD	A,(CBUFF)	;EXECUTE DEFAULT COMMAND?
	OR	A		;0=NO
	JR	NZ,RS1
;
; PROMPT USER AND INPUT COMMAND LINE FROM HIM
;
RESTRT:
	LD	SP,STACK	;RESET STACK
;
; PRINT PROMPT (DU>)
;
	CALL	CRLF		;PRINT PROMPT
	CALL	GETDRV		;CURRENT DRIVE IS PART OF PROMPT
	ADD	A,'A'		;CONVERT TO ASCII A-P
	CALL	CONOUT
	CALL	GETUSR		;GET USER NUMBER
;
	IF	SUPRES		;IF SUPPRESSING USR # REPORT FOR USR 0
	OR	A
	JR	Z,RS000
	ENDIF
;
	CP	10		;USER < 10?
	JR	C,RS00
	SUB	10		;SUBTRACT 10 FROM IT
	PUSH	AF		;SAVE IT
	LD	A,'1'		;OUTPUT 10'S DIGIT
	CALL	CONOUT
	POP	AF
RS00:
	ADD	A,'0'		;OUTPUT 1'S DIGIT (CONVERT TO ASCII)
	CALL	CONOUT
;
; READ INPUT LINE FROM USER OR $$$.SUB
;
RS000:
	CALL	REDBUF		;INPUT COMMAND LINE FROM USER (OR $$$.SUB)
;
; PROCESS INPUT LINE
;
RS1:
;
	IF	CLEVEL3		;IF THIRD COMMAND LEVEL IS PERMITTED
	CALL	CNVBUF		;CAPITALIZE COMMAND LINE, PLACE ENDING 0,
				; AND SET CIBPTR VALUE
	ENDIF
;
	CALL	DEFDMA		;SET TBUFF TO DMA ADDRESS
	CALL	GETDRV		;GET DEFAULT DRIVE NUMBER
	LD	(TDRIVE),A	;SET IT
	CALL	SCANER		;PARSE COMMAND NAME FROM COMMAND LINE
	CALL	NZ,ERROR	;ERROR IF COMMAND NAME CONTAINS A '?'
	LD	DE,RSTCPR	;PUT RETURN ADDRESS OF COMMAND
	PUSH	DE		;ON THE STACK
	LD	A,(TEMPDR)	;IS COMMAND OF FORM 'D:COMMAND'?
	OR	A		;NZ=YES
	JP	NZ,COM		; IMMEDIATELY
	CALL	CMDSER		;SCAN FOR CPR-RESIDENT COMMAND
	JP	NZ,COM		;NOT CPR-RESIDENT
	LD	A,(HL)		;FOUND IT:  GET LOW-ORDER PART
	INC	HL		;GET HIGH-ORDER PART
	LD	H,(HL)		;STORE HIGH
	LD	L,A		;STORE LOW
	JP	(HL)		;EXECUTE CPR ROUTINE
;
; ENTRY POINT FOR RESTARTING CPR AND LOGGING IN DEFAULT DRIVE
;
RSTCPR:
	CALL	DLOGIN		;LOG IN DEFAULT DRIVE
;
; ENTRY POINT FOR RESTARTING CPR WITHOUT LOGGING IN DEFAULT DRIVE
;
RCPRNL:
	CALL	SCANER		;EXTRACT NEXT TOKEN FROM COMMAND LINE
	LD	A,(FCBFN)	;GET FIRST CHAR OF TOKEN
	SUB	' '		;ANY CHAR?
	LD	HL,TEMPDR
	OR	(HL)
	JP	NZ,ERROR
	JR	RESTRT
;
; No File Error Message
;
PRNNF:
	CALL	PRINTC		;NO FILE MESSAGE
	DEFM	'No Fil'
	DEFB	'e'+80H
	RET
;
; CPR BUILT-IN COMMAND TABLE
;
NCHARS	EQU	4		;NUMBER OF CHARS/COMMAND
;
; CPR COMMAND NAME TABLE
;   EACH TABLE ENTRY IS COMPOSED OF THE 4-BYTE COMMAND AND 2-BYTE ADDRESS
;
CMDTBL:
;
	IF	INPASS AND SECURE
	DEFM	'PASS'		;ENABLE WHEEL (SYSOP) MODE
	DEFW	PASS
	ENDIF			;INPASS AND SECURE
;
	IF	DRUSER
	DEFM	'USER'		;CHANGE USER AREAS
	DEFW	USER
	ENDIF			;DRUSER
;
	IF	CPRTYP
	DEFM	'TYPE'		;TYPE A FILE TO CON:
	DEFW	TYPE
	ENDIF			;CPRTYP
;
	IF	CPRDIR
	DEFM	'DIR '		;PULL A DIRECTORY OF DISK FILES
	DEFW	DIR
	ENDIF			;CPRDIR

NRCMDS	EQU	($-CMDTBL)/(NCHARS+2)
				;PUT ANY COMMANDS THAT ARE OK TO
				;RUN WHEN NOT UNDER WHEEL MODE
				;IN FRONT OF THIS LABEL
	IF	CPRLST AND CPRTYP
	DEFM	'LIST'		;LIST FILE TO PRINTER
	DEFW	LIST
	ENDIF			;CPRLST AND CPRTYP
;
	IF	INPASS AND SECURE
	DEFM	'NORM'		;DISABLE WHEEL MODE
	DEFW	NORM
	ENDIF			;INPASS AND SECURE
;
	IF	RAS		;FOR NON-RAS
        ELSE
	DEFM	'GO  '		;JUMP TO 100H
	DEFW	GO
	DEFM	'ERA '		;ERASE FILE
	DEFW	ERA
	DEFM	'SAVE'		;SAVE MEMORY IMAGE TO DISK
	DEFW	SAVE
	DEFM	'REN '		;RENAME FILE
	DEFW	REN
	DEFM	'DFU '		;SET DEFAULT USER
	DEFW	DFU
	DEFM	'GET '		;LOAD FILE INTO MEMORY
	DEFW	GET
	DEFM	'JUMP'		;JUMP TO LOCATION IN MEMORY
	DEFW	JUMP
	ENDIF			;RAS
;
NCMNDS	EQU	($-CMDTBL)/(NCHARS+2)
;
;**** Section 3 ****
; I/O UTILITIES
;
; OUTPUT CHAR IN REG A TO CONSOLE AND DON'T CHANGE BC
;
;
; OUTPUT <CRLF>
;
CRLF:
	LD	A,CR
	CALL	CONOUT
	LD	A,LF		;FALL THRU TO CONOUT
;
CONOUT:
	PUSH	BC
	LD	C,02H
OUTPUT:
	AND	7FH		;PREVENT INADVERTANT GRAPHIC OUTPUT
				; TO EPSON-TYPE PRINTERS
	LD	E,A
	PUSH	HL
	CALL	BDOS
	POP	HL
	POP	BC
	RET
;
CONIN:
	LD	C,01H		;GET CHAR FROM CON: WITH ECHO
	CALL	BDOSB
;
; CONVERT CHAR IN A TO UPPER CASE
;
UCASE:
	CP	61H		;LOWER-CASE A
	RET	C
	CP	7BH		;GREATER THAN LOWER-CASE Z?
	RET	NC
	AND	5FH		;CAPITALIZE
	RET
;
NOECHO:
	PUSH	DE		;SAVE D
	LD	C,6		;DIRECT CONSOLE I/O
	LD	E,0FFH		;INPUT
	CALL	BDOSB
	POP	DE
	OR	A		;DID WE GET A CHAR?
	JR	Z,NOECHO	;WAIT FOR IT IF NOT, IT'S EXPECTED
	RET
;
	IF	CPRTYP
LCOUT:
	ENDIF			;CPRTYP
;
	IF	CPRTYP AND CPRLST
	PUSH	AF		;OUTPUT CHAR TO CON: OR LST: DEP ON PRFLG
PRFLG	EQU	$+1		;POINTER FOR IN-THE-CODE MODIFICATION
	LD	A,0		;2ND BYTE (IMMEDIATE ARG) IS THE PRINT FLAG
	OR	A		;0=TYPE
	JR	Z,LC1
	POP	AF		;GET CHAR
;
; OUTPUT CHAR IN REG A TO LIST DEVICE
;
LSTOUT:
	PUSH	BC
	LD	C,05H
	JR	OUTPUT
LC1:
	POP	AF		;GET CHAR
	ENDIF			;CPRTYP AND CPRLST
;
	IF	CPRTYP
	PUSH	AF
	CALL	CONOUT		;OUTPUT TO CON:
	POP	AF
	CP	LF		;CHECK FOR PAGING
	RET	NZ		;DONE IF NOT EOL YET
;
;  COUNT DOWN LINES AND PAUSE FOR INPUT (DIRECT) IF COUNT EXPIRES
;
	PUSH	HL
	LD	HL,PAGCNT	;COUNT DOWN
	DEC	(HL)
	JR	NZ,PGBAK	;JUMP IF NOT END OF PAGE
	LD	(HL),NLINES-2	;REFILL COUNTER
;
PGFLG	EQU	$+1		;POINTER TO IN-THE-CODE BUFFER PGFLG
	LD	A,0		;0 MAY BE CHANGED BY PGFLG EQUATE
	CP	PGDFLG		;PAGE DEFAULT OVERRIDE OPTION WANTED?
;
	IF	PGDFLT		;IF PAGING IS DEFAULT
	JR	Z,PGBAK		;  PGDFLG MEANS NO PAGING, PLEASE
	ELSE			;IF PAGING NOT DEFAULT
	JR	NZ,PGBAK	;  PGDFLG MEANS PLEASE PAGINATE
	ENDIF
;
	CALL	NOECHO		;GET CHAR BUT DON'T ECHO TO SCREEN
	CP	'C'-'@' 	;^C
	JP	Z,RSTCPR	;RESTART CPR
PGBAK:
	POP	HL		;RESTORE HL
	RET
	ENDIF			;CPRTYP
;
READF:
	LD	DE,FCBDN 	;FALL THRU TO READ
READ:
	LD	C,14H		;FALL THRU TO BDOSB
;
; CALL BDOS AND SAVE BC
;
BDOSB:
	PUSH	BC
	CALL	BDOS
	POP	BC
	OR	A
	RET
;
; PRINT STRING ENDING WITH ZERO BYTE OR CHAR WITH HIGH BIT SET
; PT'ED TO BY RET ADDR, START WITH <CR><LF>
;
PRINTC:
	PUSH	AF		;SAVE FLAGS
	CALL	CRLF		;NEW LINE
	POP	AF
;
PRINT:
	EX	(SP),HL		;GET PTR TO STRING
	PUSH	AF		;SAVE FLAGS
	CALL	PRIN1		;PRINT STRING
	POP	AF		;GET FLAGS
	EX	(SP),HL		;RESTORE HL AND RET ADR
	RET
;
; PRINT STRING ENDING WITH ZERO BYTE OR CHAR WITH HIGH BIT SET
; PT'ED TO BY HL
;
PRIN1:
	LD	A,(HL)		;GET NEXT BYTE
	CALL	CONOUT		;PRINT CHAR
	LD	A,(HL)		;GET NEXT BYTE AGAIN FOR TEST
	INC	HL		;PT TO NEXT BYTE
	OR	A		;SET FLAGS
	RET	Z		;DONE IF ZERO
	RET	M		;DONE IF MSB SET
	JR	PRIN1
;
; BDOS FUNCTION ROUTINES
;
;
; RETURN NUMBER OF CURRENT DISK IN A
;
GETDRV:
	LD	C,19H
	JR	BDOSJP
;
; SET 80H AS DMA ADDRESS
;
DEFDMA:
	LD	DE,TBUFF 	;80H=TBUFF
DMASET:
	LD	C,1AH
	JR	BDOSJP
;
RESET:
	LD	C,0DH
BDOSJP:
	JP	BDOS
;
LOGIN:
	LD	E,A		;MOVE DESIRED # TO BDOS REG
;
	IF	MAXDRIV
	LD	A,(MAXDRIV)	;CHECK FOR LEGAL DRIVE #
	CP	E
	JP	C,ERROR		;DON'T DO IT IF TOO HIGH
	ENDIF			;MAXDRIV
;
	LD	C,0EH
	JR	BDOSJP		;SAVE SOME CODE SPACE
;
OPENF:
	XOR	A
	LD	(FCBCR),A
	LD	DE,FCBDN 	;FALL THRU TO OPEN
;
OPEN:
	LD	C,0FH		;FALL THRU TO GRBDOS
;
GRBDOS:
	CALL	BDOS
	INC	A		;SET ZERO FLAG FOR ERROR RETURN
	RET
;
CLOSE:
	LD	C,10H
	JR	GRBDOS
;
SEARF:
	LD	DE,FCBDN 	;SPECIFY FCB
SEAR1:
	LD	C,11H
	JR	GRBDOS
;
SEARN:
	LD	C,12H
	JR	GRBDOS
;
; CHECK FOR SUBMIT FILE IN EXECUTION AND ABORT IT IF SO
;
SUBKIL:
	LD	HL,RNGSUB	;CHECK FOR SUBMIT FILE IN EXECUTION
	LD	A,(HL)
	OR	A		;0=NO
	RET	Z
	LD	(HL),0		;ABORT SUBMIT FILE
	LD	DE,SUBFCB	;DELETE $$$.SUB
;
DELETE:
	LD	C,13H
	JR	BDOSJP		;SAVE MORE SPACE
;
; RESET USER NUMBER IF CHANGED
;
RESETUSR:
TMPUSR	EQU	$+1		;POINTER FOR IN-THE-CODE MODIFICATION
	LD	A,0		;2ND BYTE (IMMEDIATE ARG) IS TMPUSR
	LD	E,A		;PLACE IN E
	JR	SETUSR		;THEN GO SET USER
GETUSR:
	LD	E,0FFH		;GET CURRENT USER NUMBER
SETUSR:
	LD	C,20H		;SET USER NUMBER TO VALUE IN E (GET IF E=FFH)
	JR	BDOSJP		;MORE SPACE SAVING
;
; END OF BDOS FUNCTIONS
;
;
;**** Section 4 ****
; CPR UTILITIES
;
; SET USER/DISK FLAG TO CURRENT USER AND DEFAULT DISK
;
SETUD:
	CALL	GETUSR		;GET NUMBER OF CURRENT USER
	ADD	A,A		;PLACE IT IN HIGH NYBBLE
	ADD	A,A
	ADD	A,A
	ADD	A,A
	LD	HL,TDRIVE	;MASK IN DEFAULT DRIVE NUMBER (LOW NYBBLE)
	OR	(HL)		;MASK IN
	LD	(UDFLAG),A	;SET USER/DISK NUMBER
	RET
;
; SET USER/DISK FLAG TO USER 0 AND DEFAULT DISK
;
SETU0D:
TDRIVE	EQU	$+1		;POINTER FOR IN-THE-CODE MODIFICATION
	LD	A,0		;2ND BYTE (IMMEDIATE ARG) IS TDRIVE
	LD	(UDFLAG),A	;SET USER/DISK NUMBER
	RET
;
; INPUT NEXT COMMAND TO CPR
;	This routine determines if a SUBMIT file is being processed
; and extracts the command line from it if so or from the user's console
;
REDBUF:
	LD	A,(RNGSUB)	;SUBMIT FILE CURRENTLY IN EXECUTION?
	OR	A		;0=NO
	JR	Z,RB1		;GET LINE FROM CONSOLE IF NOT
	LD	DE,SUBFCB	;OPEN $$$.SUB
	CALL	OPEN
	JR	Z,RB1		;ERASE $$$.SUB IF END OF FILE AND GET CMND
	LD	A,(SUBFRC)	;GET VALUE OF LAST RECORD IN FILE
REDBUF0:LD	DE,SUBFCB
	DEC	A		;PT TO NEXT TO LAST RECORD
	LD	(SUBFCR),A	;SAVE NEW VALUE OF LAST RECORD IN $$$.SUB
	PUSH	AF
	CALL	READ		;DE=SUBFCB
	POP	BC
	JR	NZ,RB1		;ABORT $$$.SUB IF ERROR IN READING LAST REC
	LD	HL,TBUFF
	XOR	A
	CP	(HL)
	LD	A,B
	JR	Z,REDBUF0
	LD	DE,CBUFF 	;COPY LAST RECORD (NEXT SUBMIT CMND) TO CBUFF FROM TBUFF
	LD	BC,BUFLEN	;NUMBER OF BYTES
	LDIR
	LD	(HL),0
	LD	DE,SUBFCB	;CLOSE $$$.SUB
	CALL	CLOSE
	JR	Z,RB1		;ABORT $$$.SUB IF ERROR
	LD	A,SPRMPT	;PRINT SUBMIT PROMPT
	CALL	CONOUT
	LD	HL,CIBUFF	;PRINT COMMAND LINE FROM $$$.SUB
	CALL	PRIN1
	CALL	BREAK		;CHECK FOR ABORT (ANY CHAR)
;
	IF	CLEVEL3		;IF THIRD COMMAND LEVEL IS PERMITTED
	RET	Z		;IF <NULL> (NO ABORT), RETURN TO CALLER AND RUN
	ENDIF
;
	IF	CLEVEL3	;IF THIRD COMMAND LEVEL IS NOT PERMITTED
        ELSE
	JR	Z,CNVBUF	;IF <NULL> (NO ABORT), CAPITALIZE COMMAND
	ENDIF
;
	CALL	SUBKIL		;KILL $$$.SUB IF ABORT
	JP	RESTRT		;RESTART CPR
;
; INPUT COMMAND LINE FROM USER CONSOLE
;
RB1:
	CALL	SUBKIL		;ERASE $$$.SUB IF PRESENT
	CALL	SETUD		;SET USER AND DISK
	LD	A,CPRMPT	;PRINT PROMPT
	CALL	CONOUT
	LD	C,0AH		;READ COMMAND LINE FROM USER
	LD	DE,MBUFF
	CALL	BDOS
;
	IF	CLEVEL3		;IF THIRD COMMAND LEVEL IS PERMITTED
	JP	SETU0D		;SET CURRENT DISK NUMBER IN LOWER PARAMS
	ENDIF
;
	IF	CLEVEL3	;IF THIRD COMMAND LEVEL IS NOT PERMITTED
        ELSE
	CALL	SETU0D		;SET CURRENT DISK NUMBER IF LOWER PARAMS
				; AND FALL THRU TO CNVBUF
	ENDIF
;
; CAPITALIZE STRING (ENDING IN 0) IN CBUFF AND SET PTR FOR PARSING
;
CNVBUF:
	LD	HL,CBUFF 	;PT TO USER'S COMMAND
	LD	B,(HL)		;CHAR COUNT IN B
	INC	B		;ADD 1 IN CASE OF ZERO
CB1:
	INC	HL		;PT TO 1ST VALID CHAR
	LD	A,(HL)		;CAPITALIZE COMMAND CHAR
	CALL	UCASE
	LD	(HL),A
	DJNZ	CB1		;CONTINUE TO END OF COMMAND LINE
CB2:
	LD	(HL),0		;STORE ENDING <NULL>
	LD	HL,CIBUFF	;SET COMMAND LINE PTR TO 1ST CHAR
	LD	(CIBPTR),HL
	RET
;
; CHECK FOR ANY CHAR FROM USER CONSOLE;RET W/ZERO SET IF NONE
;
BREAK:
	PUSH	DE		;SAVE DE
	LD	C,11		;CSTS CHECK
	CALL	BDOSB
	CALL	NZ,CONIN	;GET INPUT CHAR
BRKBK:
	POP	DE
	RET
;
; GET THE REQUESTED USER NUMBER FROM THE COMMAND LINE AND VALIDATE IT.
;
USRNUM:		
	CALL	NUMBER
;
	IF	USRMAX
	LD	HL,USRMAX 	;PT TO MAXUSR + 1
	CP	(HL)		;NEW VALUE ALLOWED?
	ELSE
	CP	MAXUSR+1 	;NEW VALUE ALLOWED?
	ENDIF			;USRMAX
;
	RET	C		;RETURN TO CALLER IF SO,
				; ELSE FLAG AS ERROR
;
; INVALID COMMAND -- PRINT IT
;
ERROR:
	CALL	CRLF		;NEW LINE
	LD	HL,(CIPTR)	;PT TO BEGINNING OF COMMAND LINE
ERR2:
	LD	A,(HL)		;GET CHAR
	CP	' '+1		;SIMPLE '?' IF <SP> OR LESS
	JR	C,ERR1
	PUSH	HL		;SAVE PTR TO ERROR COMMAND CHAR
	CALL	CONOUT		;PRINT COMMAND CHAR
	POP	HL		;GET PTR
	INC	HL		;PT TO NEXT
	JR	ERR2		;CONTINUE
ERR1:
	CALL	PRINT		;PRINT '?'
	DEFB	'?'+80H
	CALL	SUBKIL		;TERMINATE ACTIVE $$$.SUB IF ANY
	JP	RESTRT		;RESTART CPR
;
; CHECK TO SEE IF DE PTS TO DELIMITER; IF SO, RET W/ZERO FLAG SET
;
SDELM:
	LD	A,(DE)
	OR	A		;0=DELIMITER
	RET	Z
	CP	' '		;ERROR IF < <SP>
	JR	C,ERROR
	RET	Z			;<SP>=DELIMITER
	CP	'='		;'='=DELIMITER
	RET	Z
	CP	5FH		;UNDERSCORE=DELIMITER
	RET	Z
	CP	'.'		;'.'=DELIMITER
	RET	Z
	CP	':'		;':'=DELIMITER
	RET	Z
	CP	';'		;';'=DELIMITER
	RET	Z
	CP	'<'		;'<'=DELIMITER
	RET	Z
	CP	'>'		;'>'=DELIMITER
	RET
;
; ADVANCE INPUT PTR TO FIRST NON-BLANK AND FALL THROUGH TO SBLANK
;
ADVAN:
	LD	DE,(CIBPTR)
;
; SKIP STRING PTED TO BY DE (STRING ENDS IN 0) UNTIL END OF STRING
;   OR NON-BLANK ENCOUNTERED (BEGINNING OF TOKEN)
;
SBLANK:
	LD	A,(DE)
	OR	A
	RET	Z
	CP	' '
	RET	NZ
	INC	DE
	JR	SBLANK
;
; ADD A TO HL (HL=HL+A)
;
ADDAH:
	ADD	A,L
	LD	L,A
	RET	NC
	INC	H
	RET
;
; EXTRACT DECIMAL NUMBER FROM COMMAND LINE
;   RETURN WITH VALUE IN REG A;ALL REGISTERS MAY BE AFFECTED
;
NUMBER:
	CALL	SCANER		;PARSE NUMBER AND PLACE IN FCBFN
	LD	HL,FCBFN+10 	;PT TO END OF TOKEN FOR CONVERSION
	LD	B,11		;11 CHARS MAX
;
; CHECK FOR SUFFIX FOR HEXADECIMAL NUMBER
;
NUMS:
	LD	A,(HL)		;GET CHARS FROM END, SEARCHING FOR SUFFIX
	DEC	HL		;BACK UP
	CP	' '		;SPACE?
	JR	NZ,NUMS1	;CHECK FOR SUFFIX
	DJNZ	NUMS		;COUNT DOWN
	JR	NUM0		;BY DEFAULT, PROCESS
NUMS1:
	CP	NUMBASE		;CHECK AGAINST BASE SWITCH FLAG
	JR	Z,HNUM0
;
; PROCESS DECIMAL NUMBER
;
NUM0:
	LD	HL,FCBFN	;PT TO BEGINNING OF TOKEN
	LD	BC,1100H	;C=ACCUMULATED VALUE, B=CHAR COUNT
				; (C=0, B=11)
NUM1:
	LD	A,(HL)		;GET CHAR
	CP	' '		;DONE IF <SP>
	JR	Z,NUM2
	INC	HL		;PT TO NEXT CHAR
	SUB	'0'		;CONVERT TO BINARY (ASCII 0-9 TO BINARY)
	CP	10		;ERROR IF >= 10
	JR	NC,NUMERR
	LD	D,A		;DIGIT IN D
	LD	A,C		;NEW VALUE = OLD VALUE * 10
	RLCA
	RLCA
	RLCA
	ADD	A,C		;CHECK FOR RANGE ERROR
	JR	C,NUMERR
	ADD	A,C		;CHECK FOR RANGE ERROR
	JR	C,NUMERR
	ADD	A,D		;NEW VALUE = OLD VALUE * 10 + DIGIT
	JR	C,NUMERR	;CHECK FOR RANGE ERROR
	LD	C,A		;SET NEW VALUE
	DJNZ	NUM1		;COUNT DOWN
;
; RETURN FROM NUMBER
;
NUM2:
	LD	A,C		;GET ACCUMULATED VALUE
	RET
;
; NUMBER ERROR ROUTINE FOR SPACE CONSERVATION
;
NUMERR:
	JP	ERROR		;USE ERROR ROUTINE - THIS IS RELATIVE PT
;
; EXTRACT HEXADECIMAL NUMBER FROM COMMAND LINE
;   RETURN WITH VALUE IN REG A; ALL REGISTERS MAY BE AFFECTED
;
HEXNUM:
	CALL	SCANER		;PARSE NUMBER AND PLACE IN FCBFN
HNUM0:
	LD	HL,FCBFN	;PT TO TOKEN FOR CONVERSION
	LD	DE,0		;DE=ACCUMULATED VALUE
	LD	B,11		;B=CHAR COUNT
HNUM1:
	LD	A,(HL)		;GET CHAR
	CP	' '		;DONE?
	JR	Z,HNUM3		;RETURN IF SO
	CP	NUMBASE		;DONE IF NUMBASE SUFFIX
	JR	Z,HNUM3
	SUB	'0'		;CONVERT TO BINARY
	JR	C,NUMERR	;RETURN AND DONE IF ERROR
	CP	10		;0-9?
	JR	C,HNUM2
	SUB	7		;A-F?
	CP	10H		;ERROR?
	JR	NC,NUMERR
HNUM2:
	INC	HL		;PT TO NEXT CHAR
	LD	C,A		;DIGIT IN C
	LD	A,D		;GET ACCUMULATED VALUE
	RLCA			;EXCHANGE NYBBLES
	RLCA
	RLCA
	RLCA
	AND	0F0H		;MASK OUT LOW NYBBLE
	LD	D,A
	LD	A,E		;SWITCH LOW-ORDER NYBBLES
	RLCA
	RLCA
	RLCA
	RLCA
	LD	E,A		;HIGH NYBBLE OF E=NEW HIGH OF E,
				;  LOW NYBBLE OF E=NEW LOW OF D
	AND	0FH		;GET NEW LOW OF D
	OR	D		;MASK IN HIGH OF D
	LD	D,A		;NEW HIGH BYTE IN D
	LD	A,E
	AND	0F0H		;MASK OUT LOW OF E
	OR	C		;MASK IN NEW LOW
	LD	E,A		;NEW LOW BYTE IN E
	DJNZ	HNUM1		;COUNT DOWN
;
; RETURN FROM HEXNUM
;
HNUM3:
	EX	DE,HL		;RETURNED VALUE IN HL
	LD	A,L		;LOW-ORDER BYTE IN A
	RET
;
; PT TO DIRECTORY ENTRY IN TBUFF WHOSE OFFSET IS SPECIFIED BY A AND C
;
DIRPTR:
	LD	HL,TBUFF 	;PT TO TEMP BUFFER
	ADD	A,C		;PT TO 1ST BYTE OF DIR ENTRY
	CALL	ADDAH		;PT TO DESIRED BYTE IN DIR ENTRY
	LD	A,(HL)		;GET DESIRED BYTE
	RET
;
; CHECK FOR SPECIFIED DRIVE AND LOG IT IN IF NOT DEFAULT
;
SLOGIN:
	XOR	A		;SET FCBDN FOR DEFAULT DRIVE
	LD	(FCBDN),A
	CALL	COMLOG		;CHECK DRIVE
	RET	Z
	JR	DLOG5		;DO LOGIN OTHERWISE
;
; CHECK FOR SPECIFIED DRIVE AND LOG IN DEFAULT DRIVE IF SPECIFIED<>DEFAULT
;
DLOGIN:
	CALL	COMLOG		;CHECK DRIVE
	RET	Z		;ABORT IF SAME
	LD	A,(TDRIVE)	;LOG IN DEFAULT DRIVE
;
DLOG5:	JP	LOGIN
;
; ROUTINE COMMON TO BOTH LOGIN ROUTINES; ON EXIT, Z SET MEANS ABORT
;
COMLOG:
TEMPDR	EQU	$+1		;POINTER FOR IN-THE-CODE MODIFICATION
	LD	A,0		;2ND BYTE (IMMEDIATE ARG) IS TEMPDR
	OR	A		;0=NO
	RET	Z
	DEC	A		;COMPARE IT AGAINST DEFAULT
	LD	HL,TDRIVE
	CP	(HL)
	RET			;ABORT IF SAME
;
; EXTRACT TOKEN FROM COMMAND LINE AND PLACE IT INTO FCBDN;
;   FORMAT FCBDN FCB IF TOKEN RESEMBLES FILE NAME AND TYPE (FILENAME.TYP);
;   ON INPUT, CIBPTR PTS TO CHAR AT WHICH TO START SCAN;
;   ON OUTPUT, CIBPTR PTS TO CHAR AT WHICH TO CONTINUE AND ZERO FLAG IS RESET
;     IF '?' IS IN TOKEN
;
; ENTRY POINTS:
;	SCANER - LOAD TOKEN INTO FIRST FCB
;	SCANX - LOAD TOKEN INTO FCB PTED TO BY HL
;
SCANER:
	LD	HL,FCBDN 	;POINT TO FCBDN
SCANX:
	XOR	A		;SET TEMPORRY DRIVE NUMBER TO DEFAULT
	LD	(TEMPDR),A
	CALL	ADVAN		;SKIP TO NON-BLANK OR END OF LINE
	LD	(CIPTR),DE	;SET PTR TO NON-BLANK OR END OF LINE
	LD	A,(DE)		;END OF LINE?
	OR	A		;0=YES
	JR	Z,SCAN2
	SBC	A,'A'-1		;CONVERT POSSIBLE DRIVE SPEC TO NUMBER
	LD	B,A		;STORE NUMBER (A:=0, B:=1, ETC) IN B
	INC	DE		;PT TO NEXT CHAR
	LD	A,(DE)		;SEE IF IT IS A COLON (:)
	CP	':'
	JR	Z,SCAN3		;YES, WE HAVE A DRIVE SPEC
	DEC	DE		;NO, BACK UP PTR TO FIRST NON-BLANK CHAR
SCAN2:
	LD	A,(TDRIVE)	;SET 1ST BYTE OF FCBDN AS DEFAULT DRIVE
	LD	(HL),A
	JR	SCAN4
SCAN3:
	LD	A,B		;WE HAVE A DRIVE SPEC
	LD	(TEMPDR),A	;SET TEMPORRY DRIVE
	LD	(HL),B		;SET 1ST BYTE OF FCBDN AS SPECIFIED DRIVE
	INC	DE		;PT TO BYTE AFTER ':'
;
; EXTRACT FILENAME FROM POSSIBLE FILENAME.TYP
;
SCAN4:
	XOR	A		;A=0
	LD	(QMCNT),A	;INIT COUNT OF NUMBER OF QUESTION MARKS IN FCB
	LD	B,8		;MAX OF 8 CHARS IN FILE NAME
	CALL	SCANF		;FILL FCB FILE NAME
;
; EXTRACT FILE TYPE FROM POSSIBLE FILENAME.TYP
;
	LD	B,3		;PREPARE TO EXTRACT TYPE
	CP	'.'		;IF (DE) DELIMITER IS A '.', WE HAVE A TYPE
	JR	NZ,SCAN15	;FILL FILE TYPE BYTES WITH <SP>
	INC	DE		;PT TO CHAR IN COMMAND LINE AFTER '.'
	CALL	SCANF		;FILL FCB FILE TYPE
	JR	SCAN16		;SKIP TO NEXT PROCESSING
SCAN15:
	CALL	SCANF4		;SPACE FILL
;
; FILL IN EX, S1, S2, AND RC WITH ZEROES
;
SCAN16:
	LD	B,4		;4 BYTES
SCAN17:
	INC	HL		;PT TO NEXT BYTE IN FCBDN
	LD	(HL),0
	DJNZ	SCAN17
;
; SCAN COMPLETE -- DE PTS TO DELIMITER BYTE AFTER TOKEN
;
	LD	(CIBPTR),DE
;
; SET ZERO FLAG TO INDICATE PRESENCE OF '?' IN FILENAME.TYP
;
	LD	A,(QMCNT)	;GET NUMBER OF QUESTION MARKS
	OR	A		;SET ZERO FLAG TO INDICATE ANY '?'
	RET
;
;  SCANF -- SCAN TOKEN PTED TO BY DE FOR A MAX OF B BYTES; PLACE IT INTO
;    FILE NAME FIELD PTED TO BY HL; EXPAND AND INTERPRET WILD CARDS OF
;    '*' AND '?'; ON EXIT, DE PTS TO TERMINATING DELIMITER
;
SCANF:
	CALL	SDELM		;DONE IF DELIMITER ENCOUNTERED - <SP> FILL
	JR	Z,SCANF4
	INC	HL		;PT TO NEXT BYTE IN FCBDN
	CP	'*'		;IS (DE) A WILD CARD?
	JR	NZ,SCANF1	;CONTINUE IF NOT
	LD	(HL),'?'	;PLACE '?' IN FCBDN AND DON'T ADVANCE DE IF SO
	CALL	SCQ		;SCANNER COUNT QUESTION MARKS
	JR	SCANF2
SCANF1:
	LD	(HL),A		;STORE FILENAME CHAR IN FCBDN
	INC	DE		;PT TO NEXT CHAR IN COMMAND LINE
	CP	'?'		;CHECK FOR QUESTION MARK (WILD)
	CALL	Z,SCQ		;SCANNER COUNT QUESTION MARKS
SCANF2:
	DJNZ	SCANF		;DECREMENT CHAR COUNT UNTIL 8 ELAPSED
SCANF3:
	CALL	SDELM		;8 CHARS OR MORE - SKIP UNTIL DELIMITER
	RET	Z		;ZERO FLAG SET IF DELIMITER FOUND
	INC	DE		;PT TO NEXT CHAR IN COMMAND LINE
	JR	SCANF3
;
;  FILL MEMORY POINTED TO BY HL WITH SPACES FOR B BYTES
;
SCANF4:
	INC	HL		;PT TO NEXT BYTE IN FCBDN
	LD	(HL),' '	;FILL FILENAME PART WITH <SP>
	DJNZ	SCANF4
	RET
;
;  INCREMENT QUESTION MARK COUNT FOR SCANNER
;    THIS ROUTINE INCREMENTS THE COUNT OF THE NUMBER OF QUESTION MARKS IN
;    THE CURRENT FCB ENTRY
;
SCQ:
	LD	A,(QMCNT)	;GET COUNT
	INC	A		;INCREMENT
	LD	(QMCNT),A	;PUT COUNT
	RET
;
; CMDTBL (COMMAND TABLE) SCANNER
;   ON RETURN, HL PTS TO ADDRESS OF COMMAND IF CPR-RESIDENT
;   ON RETURN, ZERO FLAG SET MEANS CPR-RESIDENT COMMAND
;
CMDSER:
	LD	HL,CMDTBL	;PT TO COMMAND TABLE
;
	IF	SECURE
	LD	C,NRCMDS
	LD	A,(WHEEL)	;SEE IF NON-RESTRCTED
	CP	RESTRCT
	JR	Z,CMS1		;PASS IF RESTRCTED
	ENDIF			;SECURE
;
	LD	C,NCMNDS	;SET COMMAND COUNTER
CMS1:
	LD	DE,FCBFN 	;PT TO STORED COMMAND NAME
	LD	B,NCHARS	;NUMBER OF CHARS/COMMAND (8 MAX)
CMS2:
	LD	A,(DE)		;COMPARE AGAINST TABLE ENTRY
	CP	(HL)
	JR	NZ,CMS3		;NO MATCH
	INC	DE		;PT TO NEXT CHAR
	INC	HL
	DJNZ	CMS2		;COUNT DOWN
	LD	A,(DE)		;NEXT CHAR IN INPUT COMMAND MUST BE <SP>
	CP	' '
	JR	NZ,CMS4
	RET			;COMMAND IS CPR-RESIDENT (ZERO FLAG SET)
CMS3:
	INC	HL		;SKIP TO NEXT COMMAND TABLE ENTRY
	DJNZ	CMS3
CMS4:
	INC	HL		;SKIP ADDRESS
	INC	HL
	DEC	C		;DECREMENT TABLE ENTRY NUMBER
	JR	NZ,CMS1
	INC	C		;CLEAR ZERO FLAG
	RET			;COMMAND IS DISK-RESIDENT (ZERO FLAG CLEAR)
;
;**** Section 5 ****
; CPR-Resident Commands
;
;
;Section 5A
;Command: DIR
;Function:  To display a directory of the files on disk
;Forms:
;	DIR <afn>	Displays the DIR files
;	DIR <afn> S	Displays the SYS files
;	DIR <afn> A	Display both DIR and SYS files
;
	IF	CPRDIR
;
DIR:
	LD	A,80H		;SET SYSTEM BIT EXAMINATION
	PUSH	AF
	CALL	SCANER		;EXTRACT POSSIBLE D:FILENAME.TYP TOKEN
	CALL	SLOGIN		;LOG IN DRIVE IF NECESSARY
	LD	HL,FCBFN 	;MAKE FCB WILD (ALL '?') IF NO FILENAME.TYP
	LD	A,(HL)		;GET FIRST CHAR OF FILENAME.TYP
	CP	' '		;IF <SP>, ALL WILD
	CALL	Z,FILLQ
	CALL	ADVAN		;LOOK AT NEXT INPUT CHAR
	LD	B,0		;SYS TOKEN DEFAULT
	JR	Z,DIR2		;JUMP; THERE ISN'T ONE
	CP	SYSFLG		;SYSTEM FLAG SPECIFIER?
	JR	Z,GOTSYS	;GOT SYSTEM SPECIFIER
	CP	SOFLG		;SYS ONLY?
	JR	NZ,DIR2
	LD	B,80H		;FLAG SYS ONLY
GOTSYS:
	INC	DE
	LD	(CIBPTR),DE
	CP	SOFLG		;SYS ONLY SPEC?
	JR	Z,DIR2		;THEN LEAVE BIT SPEC UNCHAGNED
	POP	AF		;GET FLAG
	XOR	A		;SET NO SYSTEM BIT EXAMINATION
	PUSH	AF 
DIR2:
	POP	AF		;GET FLAG
DIR2A:
				;DROP INTO DIRPR TO PRINT DIRECTORY
				; THEN RESTART CPR
	ENDIF			;CPRDIR
;
; DIRECTORY PRINT ROUTINE; ON ENTRY, MSB OF A IS 1 (80H) IF SYSTEM FILES
; EXCLUDED. THIS ROUTINE IS ALSO USED BY ERA.
;
DIRPR:
	LD	D,A		;STORE SYSTEM FLAG IN D
	LD	E,0		;SET COLUMN COUNTER TO ZERO
	PUSH	DE		;SAVE COLUMN COUNTER (E) AND SYSTEM FLAG (D)
	LD	A,B		;SYS ONLY SPECIFIER
	LD	(SYSTST),A
	CALL	SEARF		;SEARCH FOR SPECIFIED FILE (FIRST OCCURRANCE)
	CALL	Z,PRNNF		;PRINT NO FILE MSG;REG A NOT CHANGED
;
; ENTRY SELECTION LOOP; ON ENTRY, A=OFFSET FROM SEARF OR SEARN
;
DIR3:
	JR	Z,DIR11		;DONE IF ZERO FLAG SET
	DEC	A		;ADJUST TO RETURNED VALUE
	RRCA			;CONVERT NUMBER TO OFFSET INTO TBUFF
	RRCA
	RRCA
	AND	60H
	LD	C,A		;OFFSET INTO TBUFF IN C (C=OFFSET TO ENTRY)
	LD	A,10		;ADD 10 TO PT TO SYSTEM FILE ATTRIBUTE BIT
	CALL	DIRPTR
	POP	DE		;GET SYSTEM BIT MASK FROM D
	PUSH	DE
	AND	D		;MASK FOR SYSTEM BIT
SYSTST	EQU	$+1		;POINTER TO IN-THE-CODE BUFFER SYSTST
	CP	0
	JR	NZ,DIR10
	POP	DE		;GET ENTRY COUNT (=<CR> COUNTER)
	LD	A,E		;ADD 1 TO IT
	INC	E
	PUSH	DE		;SAVE IT
;
	IF	TWOCOL
	AND	01H		;OUTPUT <CRLF> IF 2 ENTRIES PRINTED IN LINE
	ENDIF			;TWOCOL
;
	IF	TWOCOL
        ELSE
TWOPOK	EQU	$+1		;FOR APPLE PATCHING
	AND	03H		;OUTPUT <CRLF> IF 4 ENTRIES PRINTED IN LINE
	ENDIF			;NOT TWOCOL
;
	PUSH	AF
	JR	NZ,DIR4
	CALL	CRLF		;NEW LINE
	JR	DIR5
DIR4:
	CALL	PRINT
;
	IF	WIDE
	DEFM	'  '		;2 SPACES
	DEFB	FENCE		;THEN FENCE CHAR
	DEFB	' ',' '+80H	;THEN 2 MORE SPACES
;	ENDIF
;
        ELSE
	DEFB	' '		;SPACE
	DEFB	FENCE		;THEN FENCE CHAR
	DEFB	' '+80H		;THEN SPACE
	ENDIF
;
DIR5:
	LD	B,01H		;PT TO 1ST BYTE OF FILE NAME
DIR6:
	LD	A,B		;A=OFFSET
	CALL	DIRPTR		;HL NOW PTS TO 1ST BYTE OF FILE NAME
	AND	7FH		;MASK OUT MSB
	CP	' '		;NO FILE NAME?
	JR	NZ,DIR8		;PRINT FILE NAME IF PRESENT
	POP	AF
	PUSH	AF
	CP	03H
	JR	NZ,DIR7
	LD	A,09H		;PT TO 1ST BYTE OF FILE TYPE
	CALL	DIRPTR		;HL NOW PTS TO 1ST BYTE OF FILE TYPE
	AND	7FH		;MASK OUT MSB
	CP	' '		;NO FILE TYPE?
	JR	Z,DIR9		;CONTINUE IF SO
DIR7:
	LD	A,' '		;OUTPUT <SP>
DIR8:
	CALL	CONOUT		;PRINT CHAR
	INC	B		;INCR CHAR COUNT
	LD	A,B
	CP	12		;END OF FILENAME.TYP?
	JR	NC,DIR9		;CONTINUE IF SO
	CP	09H		;END IF FILENAME ONLY?
	JR	NZ,DIR6		;PRINT TYP IF SO
	LD	A,'.'		;PRINT DOT BETWEEN FILE NAME AND TYPE
	CALL	CONOUT
	JR	DIR6
DIR9:
	POP	AF
DIR10:
	CALL	BREAK		;CHECK FOR ABORT
	JR	NZ,DIR11
	CALL	SEARN		;SEARCH FOR NEXT FILE
	JR	DIR3		;CONTINUE
DIR11:
	POP	DE		;RESTORE STACK
	RET
;
; FILL FCB @HL WITH '?'
;
FILLQ:
	LD	B,11		;NUMBER OF CHARS IN FN & FT
FQLP:
	LD	(HL),'?'	;STORE '?'
	INC	HL
	DJNZ	FQLP
	RET
;
;Section 5B
;Command: ERA
;Function:  Erase files
;Forms:
;	ERA <afn>	Erase Specified files and print their names
;
	IF	RAS		;NOT FOR REMOTE-ACCESS SYSTEM
        ELSE
;
ERA:
	CALL	SCANER		;PARSE FILE SPECIFICATION
	CP	11		;ALL WILD (ALL FILES = 11 '?')?
	JR	NZ,ERA1		;IF NOT, THEN DO ERASES
	CALL	PRINTC
	DEFM	'All'
	DEFB	'?'+80H
	CALL	CONIN		;GET REPLY
	CP	'Y'		;YES?
ERARJ:
	JP	NZ,RESTRT	;RESTART CPR IF NOT
	CALL	CRLF		;NEW LINE
ERA1:
	CALL	SLOGIN		;LOG IN SELECTED DISK IF ANY
	XOR	A		;PRINT ALL FILES (EXAMINE SYSTEM BIT)
	LD	B,A		;NO SYS-ONLY OPT TO DIRPR
	CALL	DIRPR		;PRINT DIRECTORY OF ERASED FILES
;
	IF	EPRMPT
;
;  QUERY USER AFTER FILES ARE SEEN, AND GIVE ONE LAST CHANCE TO BACK OUT
;
	LD	A,E		;HOW MANY FILES DISPLAYED?
	OR	A
	JP	Z,RESTRT	;IF NONE, DON'T ASK OR DELETE
	CALL	PRINTC		;PROMPT
	DEFM	'Ok'
	DEFB	'?'+80H
	CALL	CONIN		;GET REPLY FOLDED
	CP	'Y'		;YES?
	JR	NZ,ERARJ	;GET OUT IF NOT
	ENDIF			;EPRMPT
;
	LD	DE,FCBDN 	;DELETE FILE(S) SPECIFIED
	JP	DELETE		;RESTART CPR AFTER DELETE
;
	ENDIF			;RAS
;
;Section 5C
;Command: LIST
;Function:  Print out specified file on the LST: Device
;Forms:
;	LIST <ufn>	Print file (NO Paging)
;
	IF	CPRLST
LIST:
	LD	A,0FFH		;TURN ON PRINTER FLAG
	JR	TYPE0
	ENDIF			;CPRLST
;
;Section 5D
;Command: TYPE
;Function:  Print out specified file on the CON: Device
;Forms:
;	TYPE <ufn>	Print file
;	TYPE <ufn> P	Print file with paging flag	
;
	IF	CPRTYP
TYPE:
	ENDIF			;CPRTYP
;
	IF	CPRTYP AND CPRLST
	XOR	A		;TURN OFF PRINTER FLAG
;
; ENTRY POINT FOR CPR LIST FUNCTION (LIST)
;
TYPE0:
	LD	(PRFLG),A	;SET FLAG
	ENDIF			;CPRTYP AND CPRLST
;
	IF	CPRTYP
	CALL	SCANER		;EXTRACT FILENAME.TYP TOKEN
	JP	NZ,ERROR	;ERROR IF ANY QUESTION MARKS
	CALL	ADVAN		;GET PGDFLG IF IT'S THERE
	LD	(PGFLG),A	;SAVE IT AS A FLAG
	JR	Z,NOSLAS	;JUMP IF INPUT ENDED
	INC	DE		;PUT NEW BUF POINTER
	EX	DE,HL
	LD	(CIBPTR),HL
NOSLAS:
	CALL	SLOGIN		;LOG IN SELECTED DISK IF ANY
	CALL	OPENF		;OPEN SELECTED FILE
	JP	Z,TYPE4		;ABORT IF ERROR
	CALL	CRLF		;NEW LINE
	LD	A,NLINES-1	;SET LINE COUNT
	LD	(PAGCNT),A
	LD	HL,CHRCNT	;SET CHAR POSITION/COUNT
	LD	(HL),0FFH	;EMPTY LINE
	LD	B,0		;SET TAB CHAR COUNTER
TYPE1:
	LD	HL,CHRCNT	;PT TO CHAR POSITION/COUNT
	LD	A,(HL)		;END OF BUFFER?
	CP	80H
	JR	C,TYPE2
	PUSH	HL		;READ NEXT BLOCK
	CALL	READF
	POP	HL
	JR	NZ,TYPE3	;ERROR?
	XOR	A		;RESET COUNT
	LD	(HL),A
TYPE2:
	INC	(HL)		;INCREMENT CHAR COUNT
	LD	HL,TBUFF 	;PT TO BUFFER
	CALL	ADDAH		;COMPUTE ADDRESS OF NEXT CHAR FROM OFFSET
	LD	A,(HL)		;GET NEXT CHAR
	AND	7FH		;MASK OUT MSB
	CP	1AH		;END OF FILE (^Z)?
	RET	Z		;RESTART CPR IF SO
;
; OUTPUT CHAR TO CON: OR LST: DEVICE WITH TABULATION
;
	IF	WSTYPE		;WORDSTAR HYPHEN CHECK
	CP	1FH		;IS CHAR WORDSTAR EOL HYPHEN?
	JR	NZ,NOHYPH	;PASS IF NOT
	LD	A,'-'		;YES, MAKE IT A REAL HYPHEN
NOHYPH:
	ENDIF			;WSTYPE
;
	CP	' '		;IS CHAR CONTROL CODE?
	JR	NC,PRT		;GO BOP CHAR COUNT AND PRINT IF NOT
	CP	CR		;IS CHAR A CR?
	JR	Z,YESCR		;IF SO, GO ZERO B THEN PRINT
	CP	FFEED		;FORM FEED?
	JR	Z,YESCR		;MANY PRINTERS RETURN CARRIAGE ON THIS
	CP	LF		;LINE FEED?
	JR	Z,NOBOP		;PRINT, BUT DON'T BOP B
	CP	BEL		;BELL?
	JR	Z,NOBOP		;GO RING BUT DON'T BOP B
	CP	TAB		;TAB?
	JR	NZ,TYPE2L	;IF NOT, NO OTHER CHOICES, TOSS CONTROL
LTAB:
	LD	A,' '		;<SP>
	CALL	LCOUT
	INC	B		;INCR POS COUNT
	LD	A,B
	AND	7
	JR	NZ,LTAB
	JR	TYPE2L
;
YESCR:	LD	B,0FFH		;COMBINE WITH INC BELOW TO GET ZERO
;
PRT:	INC	B		;INCREMENT CHAR COUNT
NOBOP:	CALL	LCOUT		;PRINT IT
;
; CONTINUE PROCESSING
;
;
TYPE2L:
	CALL	BREAK		;CHECK FOR ABORT
	JR	Z,TYPE1		;CONTINUE IF NO CHAR
	CP	'C'-'@' 	;^C?
	RET	Z		;RESTART IF SO
	JR	TYPE1
TYPE3:
	DEC	A		;NO ERROR?
	RET	Z		;RESTART CPR
TYPE4:
	JP	ERRLOG
	ENDIF			;CPRTYP
;
;Section 5E
;Command: SAVE
;Function:  To save the contents of the TPA onto disk as a file
;Forms:
;	SAVE <Number of Pages> <ufn>
;				Save specified number of pages (start at 100H)
;				from TPA into specified file; <Number of
;				Pages> is in DEC
;	SAVE <Number of Sectors> <ufn> S
;				Like SAVE above, but numeric argument specifies
;				number of sectors rather than pages
;
	IF	RAS		;NOT FOR REMOTE-ACCESS SYSTEM
        ELSE
;
SAVE:
	CALL	NUMBER		;EXTRACT NUMBER FROM COMMAND LINE
	LD	L,A		;HL=PAGE COUNT
	LD	H,0
	PUSH	HL		;SAVE PAGE COUNT
	CALL	EXTEST		;TEST FOR EXISTENCE OF FILE AND ABORT IF SO
	LD	C,16H		;BDOS MAKE FILE
	CALL	GRBDOS
	POP	HL		;GET PAGE COUNT
	JR	Z,SAVE3		;ERROR?
	XOR	A		;SET RECORD COUNT FIELD OF NEW FILE'S FCB
	LD	(FCBCR),A
	CALL	ADVAN		;LOOK FOR 'S' FOR SECTOR OPTION
	INC	DE		;PT TO AFTER 'S' TOKEN
	CP	SECTFLG
	JR	Z,SAVE0
	DEC	DE		;NO 'S' TOKEN, SO BACK UP
	ADD	HL,HL		;DOUBLE IT FOR HL=SECTOR (128 BYTES) COUNT
SAVE0:
	LD	(CIBPTR),DE	;SET PTR TO BAD TOKEN OR AFTER GOOD TOKEN
	LD	DE,TPA		;PT TO START OF SAVE AREA (TPA)
SAVE1:
	LD	A,H		;DONE WITH SAVE?
	OR	L		;HL=0 IF SO
	JR	Z,SAVE2
	DEC	HL		;COUNT DOWN ON SECTORS
	PUSH	HL		;SAVE PTR TO BLOCK TO SAVE
	LD	HL,128		;128 BYTES PER SECTOR
	ADD	HL,DE		;PT TO NEXT SECTOR
	PUSH	HL		;SAVE ON STACK
	CALL	DMASET		;SET DMA ADDRESS FOR WRITE (ADDRESS IN DE)
	LD	DE,FCBDN 	;WRITE SECTOR
	LD	C,15H		;BDOS WRITE SECTOR
	CALL	BDOSB		;SAVE BC
	POP	DE		;GET PTR TO NEXT SECTOR IN DE
	POP	HL		;GET SECTOR COUNT
	JR	Z,SAVE1		;CONTINUE IF NO WRITE ERROR
	JR	PRNLE		;GO PRINT ERROR AND RESET DMA
SAVE2:
	LD	DE,FCBDN 	;CLOSE SAVED FILE
	CALL	CLOSE
	INC	A		;ERROR?
	JR	NZ,SAVE3	;PASS IF OK
;
;  PRNLE IS ALSO USED BY MEMLOAD FOR TPA FULL ERROR
;
PRNLE:	CALL	PRINTC		;DISK OR MEM FULL
	DEFM	'Ful'
	DEFB	'l'+80H
;
SAVE3:	JP	DEFDMA		;SET DMA TO 0080 AND RESTART CPR
				; OR RETURN TO MLERR
;
; Test File in FCB for existence, ask user to delete if so, and abort if he
;  choses not to
;
EXTEST:
	CALL	SCANER		;EXTRACT FILE NAME
	JP	NZ,ERROR	;'?' IS NOT PERMITTED
	CALL	SLOGIN		;LOG IN SELECTED DISK
	CALL	SEARF		;LOOK FOR SPECIFIED FILE
	LD	DE,FCBDN	;PT TO FILE FCB
	RET	Z		;OK IF NOT FOUND
	PUSH	DE		;SAVE PTR TO FCB
	CALL	PRINTC
	DEFM	'Delete File'
	DEFB	'?'+80H
	CALL	CONIN		;GET RESPONSE
	POP	DE		;GET PTR TO FCB
	CP	'Y'		;KEY ON YES
	JP	NZ,RSTCPR	;RESTART IF NO, SP RESET EVENTUALLY
	PUSH	DE		;SAVE PTR TO FCB
	CALL	DELETE		;DELETE FILE
	POP	DE		;GET PTR TO FCB
	RET
;
	ENDIF			;RAS
;
;Section 5F
;Command: REN
;Function:  To change the name of an existing file
;Forms:
;	REN <New ufn>=<Old ufn>	Perform function
;
	IF	RAS		;NOT FOR REMOTE-ACCESS SYSTEM
        ELSE
;
REN:
	CALL	EXTEST		;TEST FOR FILE EXISTENCE AND RETURN
				; IF FILE DOESN'T EXIST; ABORT IF IT DOES
	LD	A,(TEMPDR)	;SAVE CURRENT DEFAULT DISK
	PUSH	AF		;SAVE ON STACK
REN0:
	LD	HL,FCBDN 	;SAVE NEW FILE NAME
	LD	DE,FCBDM
	LD	BC,16		;16 BYTES
	LDIR
	CALL	ADVAN		;ADVANCE CIBPTR
	CP	'='		;'=' OK
	JR	NZ,REN4
REN1:
	EX	DE,HL		;PT TO CHAR AFTER '=' IN HL
	INC	HL
	LD	(CIBPTR),HL	;SAVE PTR TO OLD FILE NAME
	CALL	SCANER		;EXTRACT FILENAME.TYP TOKEN
	JR	NZ,REN4		;ERROR IF ANY '?'
	POP	AF		;GET OLD DEFAULT DRIVE
	LD	B,A		;SAVE IT
	LD	HL,TEMPDR	;COMPARE IT AGAINST CURRENT DEFAULT DRIVE
	LD	A,(HL)		;MATCH?
	OR	A
	JR	Z,REN2
	CP	B		;CHECK FOR DRIVE ERROR
	LD	(HL),B
	JR	NZ,REN4
REN2:
	LD	(HL),B
	XOR	A
	LD	(FCBDN),A	;SET DEFAULT DRIVE
	LD	DE,FCBDN 	;RENAME FILE
	LD	C,17H		;BDOS RENAME FCT
	CALL	GRBDOS
	RET	NZ
REN3:
	CALL	PRNNF		;PRINT NO FILE MSG
REN4:
	JP	ERRLOG
;
	ENDIF			;RAS
;
;Section 5G
;Command: USER
;Function:  Change current USER number
;Forms:
;	USER <unum>	Select specified user number;<unum> is in DEC
;
	IF	DRUSER		;IF DRIVE/USER CODE OK...
USER:
	CALL	USRNUM		;EXTRACT USER NUMBER FROM COMMAND LINE
	LD	E,A		;PLACE USER NUMBER IN E
SUSER:	CALL	SETUSR		;SET SPECIFIED USER
	ENDIF			;DRUSER
RSTJP:
	JP	RCPRNL		;RESTART CPR
;
;Section 5H
;Command: DFU
;Function:  Set the Default User Number for the command/file scanner
;	     (MEMLOAD)
;	    Note: When under SECURE mode, this will select the second
;	          user area to check for programs (normally user 15).
;
;Forms:
;	DFU <unum>	Select Default User Number;<unum> is in DEC
;
	IF	RAS		;NOT FOR REMOTE-ACCESS SYSTEM
        ELSE
DFU:
	CALL	USRNUM		;GET USER NUMBER
	LD	(DFUSR),A	;PUT IT AWAY
	JR	RSTJP		;RESTART CPR (NO DEFAULT LOGIN)
	ENDIF			;NOT RAS
;
;Section 5I
;Command: JUMP
;Function:  To Call the program (subroutine) at the specified address
;	     without loading from disk
;Forms:
;	JUMP <adr>		Call at <adr>;<adr> is in HEX
;
	IF	RAS		;NOT FOR REMOTE-ACCESS SYSTEM
        ELSE
;
JUMP:
	CALL	HEXNUM		;GET LOAD ADDRESS IN HL
	JR	CALLPROG	;PERFORM CALL
;
	ENDIF			;RAS
;
;Section 5J
;Command: GO
;Function:  To Call the program in the TPA without loading
;	     loading from disk. Same as JUMP 100H, but much
;	     more convenient, especially when used with
;	     parameters for programs like STAT. Also can be
;	     allowed on remote-access systems with no problems.
;
;Form:
;	GO <parameters like for COMMAND>
;
	IF	RAS		;ONLY IF RAS
        ELSE
;
GO:	LD	HL,TPA		;Always to TPA
	JR	CALLPROG	;Perform call
;
	ENDIF			;END OF GO FOR RAS
;
;Section 5K
;Command: COM file processing
;Function:  To load the specified COM file from disk and execute it
;Forms:
;	<command>
;
COM:
	LD	A,(FCBFN)	;ANY COMMAND?
	CP	' '		;' ' MEANS COMMAND WAS 'D:' TO SWITCH
	JR	NZ,COM1		;NOT <SP>, SO MUST BE TRANSIENT OR ERROR
	LD	A,(TEMPDR)	;LOOK FOR DRIVE SPEC
	OR	A		;IF ZERO, JUST BLANK
	JP	Z,RCPRNL
	DEC	A		;ADJUST FOR LOG IN
	LD	(TDRIVE),A	;SET DEFAULT DRIVE
	CALL	SETU0D		;SET DRIVE WITH USER 0
	CALL	LOGIN		;LOG IN DRIVE
;
	IF	DRUSER		;DRIVE/USER HACKERY OK?
	CALL	USRNUM		;GET USER #, IF ANY
	LD	E,A		;GET IT READY FOR BDOS
	LD	A,(FCBFN)	;SEE IF # SPECIFIED
	CP	' '
	JR	NZ,SUSER	;SELECT IF WANTED
	ENDIF			;DRUSER
;
	JP	RCPRNL		;RESTART CPR
COM1:
	LD	A,(FCBFT)	;FILE TYPE MUST BE BLANK
	CP	' '
	JP	NZ,ERROR
	LD	HL,COMMSG	;PLACE DEFAULT FILE TYPE (COM) INTO FCB
	LD	DE,FCBFT	;COPY INTO FILE TYPE
	LD	BC,3		;3 BYTES
	LDIR
	LD	HL,TPA		;SET EXECUTION/LOAD ADDRESS
	PUSH	HL		;SAVE FOR EXECUTION
	CALL	MEMLOAD		;LOAD MEMORY WITH FILE SPECIFIED IN CMD LINE
				; (NO RETURN IF ERROR OR TOO BIG)
	POP	HL		;GET EXECUTION ADDRESS
;
; CALLPROG IS THE ENTRY POINT FOR THE EXECUTION OF THE LOADED
;   PROGRAM. ON ENTRY TO THIS ROUTINE, HL MUST CONTAIN THE EXECUTION
;   ADDRESS OF THE PROGRAM (SUBROUTINE) TO EXECUTE
;
CALLPROG:
	LD	(EXECADR),HL	;PERFORM IN-LINE CODE MODIFICATION
	CALL	DLOGIN		;LOG IN DEFAULT DRIVE
	CALL	SCANER		;SEARCH COMMAND LINE FOR NEXT TOKEN
	LD	HL,TEMPDR	;SAVE PTR TO DRIVE SPEC
	PUSH	HL
	LD	A,(HL)		;SET DRIVE SPEC
	LD	(FCBDN),A
	LD	HL,FCBDN+10H	;PT TO 2ND FILE NAME
	CALL	SCANX		;SCAN FOR IT AND LOAD IT INTO FCBDN+16
	POP	HL		;SET UP DRIVE SPECS
	LD	A,(HL)
	LD	(FCBDM),A
	XOR	A
	LD	(FCBCR),A
	LD	DE,TFCB		;COPY TO DEFAULT FCB
	LD	HL,FCBDN 	;FROM FCBDN
	LD	BC,33		;SET UP DEFAULT FCB
	LDIR
	LD	HL,CIBUFF-1
COM4:
	INC	HL
	LD	A,(HL)		;SKIP TO END OF 2ND FILE NAME
	OR	A		;END OF LINE?
	JR	Z,COM5
	CP	' '		;END OF TOKEN?
	JR	NZ,COM4
;
; LOAD COMMAND LINE INTO TBUFF
;
COM5:
	LD	B,-1		;SET CHAR COUNT
	LD	DE,TBUFF	;PT TO CHAR POS
	DEC	HL
COM6:
	INC	B		;INCR CHAR COUNT
	INC	HL		;PT TO NEXT
	INC	DE
	LD	A,(HL)		;COPY COMMAND LINE TO TBUFF
	LD	(DE),A
	OR	A		;DONE IF ZERO
	JR	NZ,COM6
;
; RUN LOADED TRANSIENT PROGRAM
;
COM7:
	LD	A,B		;SAVE CHAR COUNT
	LD	(TBUFF),A
	CALL	CRLF		;NEW LINE
	CALL	DEFDMA		;SET DMA TO 0080
	CALL	SETUD		;SET USER/DISK
;
; EXECUTION (CALL) OF PROGRAM (SUBROUTINE) OCCURS HERE
;
EXECADR	EQU	$+1		;CHANGE ADDRESS FOR IN-LINE CODE MODIFICATION
	CALL	TPA		;CALL TRANSIENT
	CALL	DEFDMA		;SET DMA TO 0080, IN CASE
				;PROG CHANGED IT ON US
	CALL	SETU0D		;SET USER 0/DISK
	CALL	LOGIN		;LOGIN DISK
	JP	RESTRT		;RESTART CPR
;
;Section 5L
;Command: GET
;Function:  To load the specified file from disk to the specified address
;Forms:
;	GET <adr> <ufn>	Load the specified file at the specified page;
;			<adr> is in HEX
;
	IF	RAS		;NOT FOR REMOTE-ACCESS SYSTEM
        ELSE
;
GET:
	CALL	HEXNUM		;GET LOAD ADDRESS IN HL
	PUSH	HL		;SAVE ADDRESS
	CALL	SCANER		;GET FILE NAME
	POP	HL		;RESTORE ADDRESS
	JP	NZ,ERROR	;MUST BE UNAMBIGUOUS
;
; FALL THRU TO MEMLOAD
;
	ENDIF			;RAS
;
; LOAD MEMORY WITH THE FILE WHOSE NAME IS SPECIFIED IN THE COMMAND LINE
;   ON INPUT, HL CONTAINS STARTING ADDRESS TO LOAD
;
;  EXIT BACK TO CALLER IF NO ERROR.  IF COM FILE TOO BIG OR
; OTHER ERROR, EXIT DIRECTLY TO MLERR.
;
MEMLOAD:
	LD	(LOADADR),HL	;SET LOAD ADDRESS
	CALL	GETUSR		;GET CURRENT USER NUMBER
	LD	(TMPUSR),A	;SAVE IT FOR LATER
	LD	(TSELUSR),A	;TEMP USER TO SELECT
;
;   MLA is a reentry point for a non-standard CP/M Modification
; This is the return point for when the .COM (or GET) file is not found the
; first time, Drive A: is selected for a second attempt
;
MLA:
	CALL	SLOGIN		;LOG IN SPECIFIED DRIVE IF ANY
	CALL	OPENF		;OPEN COMMAND.COM FILE
	JR	NZ,MLA1		;FILE FOUND - LOAD IT
;
	IF	SECURE
;
;  IF SECURE ENABLED, SEARCH CURRENT DRIVE, CURRENT USER, THEN
; IF IN WHEEL MODE, SEARCH UNDER LAST USER SET BY DFU (ORIG
; "RESUSR" AFTER WARM BOOT) ON CURRENT DRIVE. IF NOT FOUND, OR
; NOT IN WHEEL MODE, THEN SEARCH ON CURRENT DRIVE, UNDER USER
; "DEFUSR". IF STILL NOT FOUND, LOOK AT SAME SERIES OF USERS
; ON DRIVE A.
;
DFLAG	EQU	$+1		;MARK IN-THE-CODE VARIABLE
	LD	A,0		;HAVE WE CHECKED THIS DRIVE ALREADY?
	OR	A
	JR	NZ,MLA0		;PASS IF SO TO GO TO DRIVE A:
	LD	A,(WHEEL)	;RESTRICTED PROGS ALLOWED?
	CP	RESTRCT
	JR	Z,MLA00		;PASS IF NOT
	PUSH	BC		;PUSH BC
	LD	A,(DFUSR)	;LOAD DEFAULT USER
	LD	B,A		;PUT IT IN B
	LD	A,(TSELUSR)	;CHECK CURR USER
DFUSR	EQU	$+1		;DEFAULT USER LOCATION
	CP	RESUSR		;RESTRICTED USER?
	LD	A,B		;ASSUME NOT
	POP	BC		;RESTORE BC
	JR	NZ,SETTSE	;GO TRY IF NOT
MLA00:				;SS IF NOT
TSELUSR	EQU	$+1		;MARK IN-THE-CODE VARIABLE
	LD	A,0		;GET CURR USER
	SUB	DEFUSR		;IS IT UNRESTRICTED COM AREA?
	JR	Z,MLA0		;NO MORE CHOICES IF SO
	LD	(DFLAG),A	;MAKE DFLAG NON-ZERO IF NOT
	LD	A,DEFUSR	; AND TRY UNRESTRICTED COM AREA
	ENDIF			;SECURE
;
	IF	SECURE
        ELSE
DFUSR	EQU	$+1		;MARK IN-THE-CODE VARIABLE
	LD	A,DEFUSR	;GET DEFAULT USER
TSELUSR	EQU	$+1		;MARK IN-THE-CODE VARIABLE
	CP	DEFUSR		;CHECK FOR THE USER AREA..
	JR	Z,MLA0		;..EQUAL DEFAULT, AND JUMP IF SO
	ENDIF			;NOT SECURE
;
SETTSE:
	LD	(TSELUSR),A	;PUT DOWN NEW ONE
	LD	E,A
	CALL	SETUSR		;GO SET NEW USER NUMBER
	JR	MLA		;AND TRY AGAIN
;
; ERROR ROUTINE TO SELECT DRIVE A: IF DEFAULT WAS ORIGINALLY SELECTED
;
MLA0:
	LD	HL,TEMPDR	;GET DRIVE FROM CURRENT COMMAND
	XOR	A		;A=0
;
	IF	SECURE
	LD	(DFLAG),A	;ALLOW A: SEARCH
	ENDIF			;SECURE
;
	OR	(HL)
	JP	NZ,MLERR	;ERROR IF ALREADY DISK A:
	LD	(HL),1		;SELECT DRIVE A:
	LD	A,(TMPUSR)	;GO TO 'CURRENT' USER CODE
	JR	SETTSE
;
; FILE FOUND -- PROCEED WITH LOAD
;
MLA1:
LOADADR	EQU	$+1
	LD	HL,TPA
ML2:
	LD	A,ENTRY/256-1	;GET HIGH-ORDER ADR OF JUST BELOW CPR
	CP	H		;ARE WE GOING TO OVERWRITE THE CPR?
	JR	C,ML4		;ERROR IF SO
	PUSH	HL		;SAVE ADDRESS OF NEXT SECTOR
	EX	DE,HL		;... IN DE
	CALL	DMASET		;SET DMA ADDRESS FOR LOAD
	LD	DE,FCBDN 	;READ NEXT SECTOR
	CALL	READ
	POP	HL		;GET ADDRESS OF NEXT SECTOR
	JR	NZ,ML3		;READ ERROR OR EOF?
	LD	DE,128		;MOVE 128 BYTES PER SECTOR
	ADD	HL,DE		;PT TO NEXT SECTOR IN HL
	JR	ML2
;
ML3:
	DEC	A		;LOAD COMPLETE
	JP	Z,RESETUSR	;IF ZERO, OK, GO RESET CORRECT USER #
				; ON WAY OUT, ELSE FALL THRU TO PRNLE
;
;  TPA FULL
;
ML4:	CALL	PRNLE		;PRINT MSG AND RESET DEF DMA
;
; TRANSIENT LOAD ERROR
;
MLERR:
				;NOTE THAT THERE IS AN EXTRA RETURN ADDRESS ON
				; THE STACK. IT WILL BE TOSSED WHEN ERROR EXITS
				; TO RESTRT, WHICH RELOADS SP.
	CALL	RESETUSR	;RESET CURRENT USER NUMBER
				;  RESET MUST BE DONE BEFORE LOGIN
ERRLOG:
	CALL	DLOGIN		;LOG IN DEFAULT DISK
	JP	ERROR		;FLAG ERROR
;
;
;Section: 5M
;PASS:  Enable wheel mode.
;NORM:	Disable wheel mode.
;
;  Type PASS <password> <cr> to CP/M prompt to enter wheel mode.
; This code can be replaced with PST's PASS.ASM which gives many
; nice little options like no keyboard echo, etc.
;
	IF	INPASS		;WE WANT TO USE THIS CODE, NOT PASS.COM
PASS:
	LD	HL,PASSWD	;SET UP POINTERS
	LD	DE,CIBUFF+NCHARS+1
	LD	B,PRGEND-PASSWD	;B= LENGTH
CKPASS:	LD	A,(DE)		;TRIAL PW TO A
	CP	(HL)		;CHECK FOR MATCH
	JP	NZ,COM		;NOPE.. LOOK FOR PASS.COM
	INC	HL		;INCREMENT COUNTER
	INC	DE
	DJNZ	CKPASS		;CONTINUE IF MORE
	LD	A,NOT RESTRCT	;WHEEL = NOT RESTRCT

PWOUT:	LD	(WHEEL),A
	JP	RESTRT
;
NORM:
	LD	A,RESTRCT
	JR	PWOUT
;
PASSWD:
	DEFM	'YOURPW'	;YOUR PASSWORD
PRGEND	EQU	$		;END OF PASSWORD
;
	ENDIF			;INPASS

        DEFS    4
;
;; 	IF	($ GE CPRLOC+800H)
;; 	.PRINTX	/ZCPR exceeds 2K memory size !!!/
;; 	ENDIF
;; ;
;; 	END

