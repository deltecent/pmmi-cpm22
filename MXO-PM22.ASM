	Title	'MEX overlay for the PMMI version 2.2'
;
; Ignore the Title error message if using ASM.
;
REV	equ	22		; overlay revision number
LVL	equ	'c'		; overlay level ( as in Revision 2.2a )
;
; MEX PMMI OVERLAY VERSION 1.0: written 04/27/84            by Ron Fowler
;
;  "   "      "       "    2.0: generally rewritten 9/18/84 by Fred M. Spinner
;  "   "      "       '    2.1: rewritten 09/27/84 by Bill Norris
;  "   "      "       "    2.2:     "     10/30/84 by Bill Norris
;
;
; Version 2.2 notes:		Added 'SET EXTRA' command.  This is a toggle
;				  that allows you to see on the console when
;				  certain overlay functions are invoked.
;				Corrected a minor bug in the clear screen and
;				  clear to end of screen functions.
;				Added 15 to SET PPS command.
;				Added SET ONLINE ( SET OFFHOOK synonym )
;				OFF-HOOK and ON-HOOK have been changed from
;				  scattered in-line calls to subroutines.
;				Renamed SET FIDGET to SET ICD (intercall delay)
;				Renamed SET IDG    to SET IDD (interdigit delay)
;				The default PMMI base port was changed to 80h
;				  in version 2.1 due to conflicts with several
;				  disk controller boards.  If your PMMI is not
;				  addressed at this port, just use the SET BASE
;				  command (and CLONE) if you don't want to edit
;				  and re-assemble this file.
;				Speeded up keyboard abort (^X and ^C). ^S also
;				  accepted here (during dialing of a number).
;				Phone number '#' is replaced at dial time from
;				  the keyboard.
;
;
; Version 2.1 notes:		Unifies scattered PMMI I/O; allows modification
;				  of the PMMI base port with SET BASE command.
;				No PMMI I/O is done in-line.  It is all done
;				  using subroutine calls.  This should make all
;				  modifications simpler (including future
;				  changes to support MEX 2.x).
;				Base port address is printed in signon message.
;				SET FIDGET added (delay between calls).
;				BASE/FIDGET changes are preserved through CLONEs.
;				Uses BDOS 6 to force BUSY instead of using hard
;				coded keyboard I/O for the CTRLX function. (See
;				description in Version 2.0 notes below).
;
;
; Version 2.0 9/18/84:  Numerous bugs repaired.  The offhook command
; now actually takes the modem off hook.  The DTR bytes were swapped
; in 1.1 so that baud rates over 300 would barf.  This has been repaired
; The SET MODE command is no longer available.  Use SET ORIG, ORG, or
; ORIGINATE and SET ANS or ANSWER to switch modes.  The actual routine
; to switch modes has been re-written from scratch, also.  Overlay version
; message more verbose (better looking, also) now.  If your know your  
; keyboard (terminal)'s Status and Data Port and also know the value
; (bit) to check for for keyboard input, you can also implement the CTRLX
; feature which is handy to have if you know a number is busy and you
; want to call the next, etc. without further delays.  The keyboard info
; goes under KSTAT, KPORT, KBIT, and KVAL which mean Keyboard/Terminal status 
; port, Keyboard data port, AND bit to status input, and value to check for
; after status is ANDed, respectively.   Set CTRLX to YES if you have
; this information and want to use this feature, or set it to NO to use
; the standard MEX keyboard trap.
;
;				Fred M. Spinner
;
;
; (V1.1) 05/17/84 (Jim Byram) : Small bugs repaired.  Answer-mode
; bit (ANBIT) and originate-mode bit (ORBIT) were reversed; fixed
; SET MODE help message.
;
; This is a MEX overlay file for the PMMI modem.  You can use it as
; a model for designing your own modem overlay (or you can use any
; existing MDM7 overlay, if available).
;
; If you use this as a template for writing your own overlay, and
; distribute it to others, please pare down these comments as much
; as possible (to keep the overlays small). I'll maintain this file
; with as many notes and references as possible, but this will hope-
; fully be the only "big" overlay.
;
; There are advantages to recoding your overlay to conform to the
; techniques presented here: MEX 2.0 will likely have a much simpler
; overlay structure; if you stick to the label names and coding
; suggestions used here, you'll easily be able to follow the overlay
; upgrade instructions when MEX 2.0 hits the streets. Also, you can
; make use of the MEX service processor to write a very versatile
; SET command (as done here).
;
; Note that all overlays may freely use memory up to 0CFFH.  If your
; overlay must work with the MEX Smartmodem overlay (MXO-SMxx.ASM),
; the physical modem overlay should terminate by 0AFFH.
;
; For purposes of example, this is a "full-featured" MEX overlay.  In
; practice, your overlay may be much simpler (all that is really re-
; quired is the modem I/O code; fancy stuff like the SET command, and
; even the disconnect routine, may be left open.  You will need DIAL
; code, though, unless your modem doesn't support autodialing).
;
;------------------------------------------------------------
;
; Misc equates
;
NO	equ	0
YES	equ	0FFh
TPA	equ	100h
CR	equ	13
LF	equ	10
BS	equ	8
TAB	equ	9
ESC	equ	27
CTRLX	equ	YES		;YES, if use ^X for fake "BUSY"
CONTX	equ	'X'-40h


;
; Equates used only by PMMI routines grouped together here.
;
;
; PMMI port definitions
;
PORT	equ	080h		;PMMI base port (data or status)
				; PORT now also used by NITMOD.

MODCT1	equ	0		;modem control port (added to base port).
MODDAT	equ	MODCT1+1	;modem data port      "
BAUDRP	equ	MODCT1+2	;modem baud rate port "
MODCT2	equ	MODCT1+3	;modem status port    "
;
; PMMI bit definitions
;
MDRCVB	equ	02h		;modem receive bit (DAV)
MDRCVR	equ	02h		;modem receive ready
MDSNDB	equ	01h		;modem send bit
MDSNDR	equ	01h		;modem send ready bit
;
; 
CTSMSK	equ	4		;mask for CTS bit
BRKMSK	equ	0FBh		;mask to set break
PARMSK	equ	0CFh		;mask to remove parity bits
OPARIT	equ	00h		;odd-parity bits
EPARIT	equ	20h		;even-parity bits
NPARIT	equ	10h		;no-parity bits
MODEMK	equ	0FCh		;mode mask
ANMODE	equ	1Eh		;answer mode
ANBIT	equ	2		;answer-mode bit
ORIGMD	equ	1Dh		;originate mode
ORBIT	equ	1		;originate-mode bit
WTCTS	equ	150		;number of seconds (x5) to wait for the
				;computer to answer after PMMI auto-dial
				;100=20 sec, 150=30 sec, 255=51 sec.
				;any number 0-255 acceptable
;
;	
; Modem control command words
;
BRKMASK	equ	0		;tele line on hook (break while dialing)
CLEAR	equ	3Fh		;idle mode
DTMSK	equ	1		;dial tone mask
MAKEM	equ	1		;tele line make (off hook)
RBLMT	equ	35		;7 seconds to wait til no-ring-heard msg
RBWAIT	equ	50		;5 second delay before redialing PMMI
SMRWT	equ	15		;1.5 sec delay before redialing HAYES
TMPUL	equ	80h		;timer pulses mask bit
TRATE	equ	250		;value for 0.1 second
;
;
; MEX service processor stuff ... MEX supports an overlay service
; processor, located at 0D00H (and maintained at this address from
; version to version).  If your overlay needs to call BDOS for any
; reason, it should call MEX instead; function calls below about
; 240 are simply passed on to the BDOS (console and list I/O calls
; are specially handled to allow modem port queueing, which is why
; you should call MEX instead of BDOS).  MEX uses function calls
; above about 244 for special overlay services (described below).
;
; Some sophisticated overlays may need to do file I/O; if so, use
; the PARSFN MEX call with a pointer to the FCB in DE to parse out
; the name.  This FCB should support a spare byte immediately pre-
; ceeding the actual FCB (to contain user # information).  If you've
; used MEX-10 for input instead of BDOS-10 (or you're parsing part
; of a SET command line that's already been input), then MEX will
; take care of DU specs, and set up the FCB accordingly.  There-
; after all file I/O calls done through the MEX service processor
; will handle drive and user with no further effort necessary on
; the part of the programmer.
;
MEX	equ	0D00h		;address of the service processor
INMDM	equ	255		;get char from port to A, CY=no more in 100 ms
TIMER	equ	254		;delay 100ms * reg B
TMDINP	equ	253		;B=# secs to wait for char, cy=no char
CHEKCC	equ	252		;check for ^C from KBD, Z=present
SNDRDY	equ	251		;test for modem-send ready
RCVRDY	equ	250		;test for modem-receive ready
SNDCHR	equ	249		;send a character to the modem (after sndrdy)
RCVCHR	equ	248		;recv a char from modem (after rcvrdy)
LOOKUP	equ	247		;table search: see CMDTBL comments for info
PARSFN	equ	246		;parse filename from input stream
BDPARS	equ	245		;parse baud-rate from input stream
SBLANK	equ	244		;scan input stream to next non-blank
EVALA	equ	243		;evaluate numeric from input stream
LKAHED	equ	242		;get nxt char w/o removing from input
GNC	equ	241		;get char from input, cy=1 if none
ILP	equ	240		;inline print
DECOUT	equ	239		;decimal output
PRBAUD	equ	238		;print baud rate
;
;
CONOUT	equ	2		;simulated BDOS function 2: console char out
PRINT	equ	9		;simulated BDOS function 9: print string
INBUF	equ	10		;input buffer, same structure as BDOS 10
;
	org	TPA		;we begin
;
;
	ds	3		;MEX has a JMP START here
;
; The following variables are located at the beginning of the program
; to facilitate modification without the need of re-assembly. They will
; be moved in MEX 2.0.
;
PMODEM:	db	YES		;yes=PMMI modem \ / These 2 locations are not
SMODEM:	db	NO		;yes=Smartmodem / \ referenced by MEX
TPULSE:	db	'T'		;T=touch, P=pulse (not referenced by MEX)
CLOCK:	db	20		;clock speed x .1, up to 25.5 mhz.
MSPEED:	db	1		;sets display time for sending a file
				;0=110	1=300  2=450  3=600  4=710
				;5=1200 6=2400 7=4800 8=9600 9=19200
BYTDLY:	db	5		;default time to send character in
				;terminal mode file transfer (0-9)
				;0=0 delay, 1=10 ms, 5=50 ms, 9=90 ms
CRDLY:	db	5		;end-of-line delay after CRLF in terminal
				;mode file transfer for slow BBS systems
				;0=0 delay, 1=100 ms, 5=500 ms, 9=900 ms
COLUMS:	db	5		;number of directory columns
SETFL:	db	YES		;yes=user-defined SET command
SCRTST:	db	NO		;yes=if home cursor and clear screen
				;routine at CLRSCRN
	db	0		;was once ACKNAK, now spare
BAKFLG:	db	NO		;yes=make .BAK file
CRCDFL:	db	YES		;yes=default to CRC checking
				;no=default to Checksum checking
TOGCRC:	db	YES		;yes=allow toggling of Checksum to CRC
CVTBS:	db	NO		;yes=convert backspace to rub
TOGLBK:	db	YES		;yes=allow toggling of bksp to rub
ADDLF:	db	NO		;no=no LF after CR to send file in
				;terminal mode (added by remote echo)
TOGLF:	db	YES		;yes=allow toggling of LF after CR
TRNLOG:	db	YES		;yes=allow transmission of logon
				;write logon sequence at location LOGON
SAVCCP:	db	YES		;yes=do not overwrite CCP
LOCNXT:	db	NO		;yes=local cmd if EXTCHR precedes
				;no=not local cmd if EXTCHR precedes
TOGLOC:	db	YES		;yes=allow toggling of LOCNXTCHR
LSTTST:	db	YES		;yes=allow toggling of printer on/off
				;in terminal mode. Set to no if using
				;the printer port for the modem
XOFTST:	db	NO		;yes=allow testing of XOFF from remote
				;while sending a file in terminal mode
XONWT:	db	NO		;yes=wait for XON after sending CR while
				;transmitting a file in terminal mode	
TOGXOF:	db	YES		;yes=allow toggling of XOFF testing
IGNCTL:	db	NO		;yes=do not send control characters
				;above CTL-M to CRT in terminal mode
				;no=send any incoming CTL-char to CRT
EXTRA1:	db	0		;for future expansion
EXTRA2:	db	0		;for future expansion
BRKCHR:	db	'@'-40h		;^@ = Send a 300 ms. break tone
NOCONN:	db	'N'-40h		;^N = Disconnect from phone line
LOGCHR:	db	'L'-40h		;^L = Send logon
LSTCHR:	db	'P'-40h		;^P = Toggle printer
UNSVCH:	db	'R'-40h		;^R = Close input text buffer
TRNCHR:	db	'T'-40h		;^T = Transmit file to remote
SAVCHR:	db	'Y'-40h		;^Y = Open input text buffer
EXTCHR:	db	'^'-40h		;^^ = Send next character
PRATE:	db	167		;125=20pps dialing, 250=10pps
	db	0		;not used
;
; Low-level modem I/O routines: this will be replaced with
; a jump table in MEX 2.0 (you can insert jumps here to longer
; routines if you'd like ... I'd recommend NOT putting part of
; a routine in this area, then jumping to the rest of the routine
; in the non-fixed area; that will complicate the 2.0 conversion)

INCTL1:	jmp	iCTL1		;in modem control port
	db	0,0,0,0,0,0,0

OTDATA:	jmp	oDATA
	db	0,0,0,0,0,0,0

INPORT:	jmp	iDATA
	db	0,0,0,0,0,0,0


; Bit-test routines.  These will be merged with the above
; routines in MEX 2.0 to provide a more reasonable format
;
MASKR:	ani MDRCVB		;bit to test for receive ready
	ret
TESTR:	cpi MDRCVR		;value of receive bit when ready
	ret
MASKS:	ani MDSNDB		;bit to test for send ready
	ret
TESTS:	cpi MDSNDR		;value of send bit when ready
	ret

;
; Unused area: was once used for special PMMI functions,
; Now used only to retain compatibility with MDM overlays.
; You may use this area for any miscellaneous storage you'd
; like but the length of the area *must* be 12 bytes.
;
	ds	12
;
; Special modem function jump table: if your overlay cannot handle
; some of these, change the jump to "DS 3", so the code present in
; MEX will be retained.  Thus, if your modem can't dial, change the
; JMP PDIAL at DIALV to DS 3, and MEX will print a "not-implemented"
; diagnostic for any commands that require dialing.
;
; DIALV  dials the digit in A. See the comments at PDIAL for specs.
;
; DISCV  disconnects the modem
;
; GOODBV is called just before MEX exits to CP/M.  If your overlay
;        requires some exit cleanup, do it here.
;
; INMODV is called when MEX starts up; use INMODV to initialize the modem.
;
; NEWBDV is used for phone-number baud rates and is called with a baud-rate
;        code in the A register, value as follows:
;
;	 A=0:   110 baud       A=1:   300 baud      A=2:   450 baud
;	 A=3:   600 baud       A=4:   710 baud      A=5:  1200 baud
;	 A=6:  2400 baud       A=7:  4800 baud      A=8: 19200 baud
;
;        If your overlay supports the passed baud rate, it should store the
;	 value passed in A at MSPEED (107H), and set the requested rate. If
;	 the value passed is not supported, you should simply return (with-
;	 out modifying MSPEED) -or- optionally request a baud-rate from the
;	 user interactively.
;
; NOPARV is called at the end of each file transfer; your overlay may simply
;	 return here, or you may want to restore parity if you set no-parity
;	 in the following vector (this is the case with the PMMI overlay).
;	 
; PARITV is called at the start of each file transfer; your overlay may simply
;	 return here, or you may want to enable parity detection (this is the
;	 case with the PMMI overlay).
;
; SETUPV is the user-defined command ... to use this routine to build your own
;	 MEX command, set the variable SETFL (117H) non-zero, and add your SET
;	 code.  You can use the routine presented in the PMMI overlay as a 
;	 guide for parsing, table lookup, etc.
;
; SPMENU is provided only for MDM compatibility, and is not used by MEX 1.0 for
;	 any purpose (it will be gone in MEX 2).
;
; VERSNV is called immediately after MEX prints its sign-on message at cold
;	 startup -- use this to identify your overlay in the sign-on message
;	 (include overlay version number in the line).
; BREAKV is provided for sending a BREAK (<ESC>-B in terminal mode).  If your
;	 modem doesn't support BREAK, or you don't care to code a BREAK rou-
;	 tine, you may simply execute a RET instruction.
;
LOGON:	ds	2		;needed for MDM compat, not ref'd by MEX
DIALV:	jmp	PDIAL		;dial digit in A (see info at PDIAL)
DISCV:	jmp	PDISC		;disconnect the modem
GOODBV:	jmp	DUMMY		;called before exit to CP/M
INMODV:	jmp	NITMOD		;initialization. Called at cold-start
NEWBDV:	jmp	PBAUD		;set baud rate
NOPARV:	jmp	NOPAR		;set modem for no-parity
PARITV:	jmp	PARITY		;set modem parity
SETUPV:	jmp	SETCMD		;SET cmd: jump to a RET if you don't write SET
SPMENV:	ds	3		;not used with MEX
VERSNV:	jmp	SYSVER		;Overlay's voice in the sign-on message
BREAKV:	jmp	PBREAK		;send a break
;
; The following jump vector provides the overlay with access to special
; routines in the main program (retained and supported in the main pro-
; gram for MDM overlay compatibility). These should not be modified by
; the overlay.
;
; Note that for MEX 2.0 compatibility, you should not try to use these
; routines, since this table will go away with MEX 2.0 (use the MEX
; service call processor instead).
;
ILPRTV:	ds	3		;replace with MEX function 9
INBUFV:	ds	3		;replace with MEX function 10
ILCMPV:	ds	3		;replace with table lookup funct. 247
INMDMV:	ds	3		;replace with MEX function 255
NXSCRV:	ds	3		;not supported by MEX (returns w/no action)
TIMERV:	ds	3		;replace with MEX function 254
;
;
; Clear/screen and clear/end-of-screen. Each routine must use the
; full 9 bytes alloted (may be padded with nulls).
;
; These routines (and other screen routines that MEX 2.0 will sup-
; port) will be accessed through a jump table in 2.0, and will be
; located in an area that won't tie the screen functions to the
; modem overlay (as the MDM format does).
;

CLREOS:	lxi	h,SCRTST
	lxi	d,EOSMSG
	jmp	PRMAYBE


CLS:	lxi	h,SCRTST
	lxi	d,CLSMSG
	jmp	PRMAYBE

;
;------------------------------------------------------------
;
;	*** END OF FIXED FORMAT AREA ***
;
;------------------------------------------------------------
;

; Data area
ERRFLG:	db	0		;connection error code
UCTLB:	db	ORIGMD		;uart-control byte image
BAUDSV:	db	52		;current baud rate (dflt 300)
MODCTB:	db	07FH		;modem control byte
INTERD:	db	2		;inter-digit delay in 100's of ms
PRXTRA:	db	YES		; Diagnostic prints upon function usage
WTNUM:	db	WTCTS		;
OFFHK:	db	0		;
				;
BPTAB:	db	'0123456789ABCDEF', 80h
NITBYT:	db	PORT		; Should be the PMMI base port.  Original port
				; is C0 hex.  Recommended alternate is 80 hex.
DIALFLG: db	0		;
ABOBYT:	db	0		;
TEMP:	dw	0		;


PRMAYBE: mov	a,m
	ora	a
	rz
PRMBOK:	mvi	c,PRINT
	jmp	MEX

iCTL1:	mvi	a,MODCT1
	jmp	BPIN
iCTL2:	mvi	a,MODCT2
	jmp	BPIN
iDATA:	mvi	a,MODDAT	;in modem data port
	jmp	BPIN
iBDRP:	mvi	a,BAUDRP
	jmp	BPIN

oCTL1:	push	psw
	mvi	a,MODCT1
	jmp	BPOUT
oCTL2:	push	psw
	mvi	a,MODCT2
	jmp	BPOUT
oDATA:	push	psw		;out modem data port
	mvi	a,MODDAT
	jmp	BPOUT
oBDRP:	push	psw
	mvi	a,BAUDRP
	jmp	BPOUT

BPIN:	push	b
	mov	b,a
	lda	NITBYT
	add	b
	sta	BPINX+1
BPINX:	in	$-$
	pop	b
	ret

BPOUT:	push	b
	mov	b,a
	lda	NITBYT
	add	b
	sta	BPOUTX+1
	pop	b
	pop	psw
BPOUTX:	out	$-$
	ret


; Modem initialization.  This overlay doesn't do any initialization.
; (if we did, we'd disconnect a call already in progress).

NITMOD:	lda	NITBYT		; Convert hex byte to ascii nibble.
	rar
	rar
	rar
	rar
	ani	0Fh
	mvi	d,0
	mov	e,a
	lxi	h,BPTAB
	dad	d
	mov	a,m
	sta	BPMSG		; Store base port in sign-on message.
	mvi	a,LVL
	sta	LEVEL
	ret


; PMMI send-break routine
PBREAK:	lda	MODCTB		;get the last modem control byte
	ani	BRKMSK		;set the transmit break bit low
	call	oCTL2		;send it to the modem
	mvi	b,2
	call	TIMERV		;send a space tone for 200 ms.
	lda	MODCTB		;get the last modem control byte
	call	oCTL2		;restore to normal
	lxi	h,PRXTRA
	lxi	d,BRKMSG
	jmp	PRMAYBE

BRKMSG:	db	'.break. $'


;  Setup PMMI for odd/even parity.
PARITY:	lda	UCTLB		;send what's in the image byte
	jmp	oCTL1


; set no-parity
NOPAR:	lda	UCTLB		;get uart/modem control byte
	ani	PARMSK		;reset parity bits
	ori	NPARIT		;add no-parity bits
	jmp	oCTL1


; disconnect the modem
PDISC:	call	HUKONN		; Hang up
	call	oCTL2		; clear DAV, ESD, etc
	push	b		;
	lxi	h,PRXTRA	;
	lxi	d,DSC1MSG	;
	call	PRMAYBE		;
	mvi	b,20		;wait for PMMI to disconnect (2 sec) %%* 1 to 2
	mvi	c,TIMER		;0.1 second per timer interval
	call	MEX		;
	lxi	h,PRXTRA	;
	lxi	d,DSC2MSG	;
	call	PRMAYBE		;
	pop	b		;
	ret			;

DSC1MSG: db	'.di$'
DSC2MSG: db	'sc. $'

; exit routine
DUMMY:	ret			;we don't need one
;
;
;------------------------------------------------------------
;
;		<PMMI DIALING ROUTINES BEGIN>
;
; This is the DIAL routine called by MEX to dial a digit. The digit
; to be dialed is passed in the A register.  Note that two special
; codes must be intercepted as non-digits: 254 (start dial sequence)
; and 255 (end-dial sequence).  Mex will always call DIAL with 254
; in the accumulator prior to dialing a number.  Mex will also call
; dial with 255 in A as an indication that dialing is complete. Thus,
; the overlay may use these values to "block" the number, holding it
; in a buffer until it is completely assembled (we don't do this with
; the PMMI, however; we just dial the digits as they come in).
;
; After the 254-start-dial sequence, MEX will call the overlay with
; digits, one-at-a-time.  MEX will make no assumptions about the dig-
; its, and will send each to the DIAL routine un-inspected (some modems,
; like the Smartmodem, allow special non-numeric characters in the
; phone number, and MEX may make no assumptions about these). This
; dialing routine validates digits, and ignores any except 0-9 and
; comma (uses comma to simulate Smartmodem delay).
;
; After receiving the end-dial sequence (255) the overlay must take
; whatever end-of-dial actions are necessary *including* waiting for
; carrier at the distant end.  The overlay should monitor the keyboard
; during this wait (using the MEX keystat service call), and return
; an exit code to MEX in the A register, as follows:
;
;	0 - Carrier detected, connection established
;	1 - Far end busy (only for modems that can detect this condition)
;	2 - No answer (or timed out waiting for modem response)
;	3 - Keyboard abort (^C only: all others should be ignored)
;	4 - Error reported by modem
;
; <No other codes should be returned after an end-dial sequence>
;
; The overlay should not loop forever in the carrier-wait routine, but
; instead use either the overlay timer vector, or the INMDMV (timed 100
; ms character wait) service call routine.
;
; The DIAL routine is free to use any of the registers, but must return
; the above code after an end-dial sequence
;
;
PDIAL:	cpi	254		;start-dial?
	jz	STDIAL		;
	cpi	255		;end-dial
	jz	ENDIAL		;
				;
	push	psw		;
	mvi	a,7		;
	sta	DIALFLG		;
	pop	psw		;
				;
PDIAL1:	cpi	','		;smartmodem pause command
	jnz	PDIAL2		;if not pause, continue
	mvi	b,10		;delay 1 second
	jmp	TIMOUT		;


PDIAL2:	cpi	'#'		;
	jnz	CKDIG		;
	mvi	a,BS		;
	call	PUT1C		;
PDIAL3:	call	GET1C		;
	jz	PDIAL3		;
	call	PUT1C		;
	jmp	PDIAL1		;


CKDIG:	cpi	'9'+1		; digits are 0-9
	rnc			; too big...
	sui	'0'		;
	rc			; too small....
	jnz	DIALIT		; just right...
	mvi	a,10		; convert zero to 10 pulses

; Send a digit to the modem.
DIALIT:	mov	c,a		; save the digit
	lda	ERRFLG		; before we try to dial...
	ora	a		; ...check dialtone error flag
	rnz			; ...if no DT, exit now
	lda	PRATE		; value for dial speed
	call	oBDRP		;
	call	WAITLO		; wait for timer lo
	call	WAITHI		; wait for timer hi

	call	GET1C		;
DIAL1:	cpi	3		; ^C ?
	jz	DIALX		;
	cpi	24		; ^X ?
	jz	DIALX		;
	cpi	19		; ^S ?
	jnz	DIGLP		;

DIALP:	call	GET1C		; Wait for a character
	jz	DIALP		;
	cpi	19		;
	jmp	DIGLP		;
				;
DIALX:	sta	ABOBYT		;

DIGLP:	lda	ABOBYT		;
	ora	a		;
	jnz	DIGLP2		;
				;
	call	HUKOFF		; Go off-hook
	call	WAITLO		;
	call	HUKONN		;
	call	WAITHI		;
DIGLP2:	dcr	c		;
	jnz	DIGLP		; send rest of digit
	lda	ABOBYT		;
	ora	a		;
	rnz			;
				;
	call	HUKOFF		;
	lda	INTERD		; get inter-digit delay
	mov	b,a		;
	jmp	TIMOUT		;


; Wait for  negative edge of timer pulse
WAITLO:	call	iBDRP
	ani	TMPUL
	jnz	WAITLO
	ret


; Wait for positive edge of timer pulse
WAITHI:	call	iBDRP
	ani	TMPUL
	jz	WAITHI
	ret


; Start-dial sequence: disconnect, wait for dial-tone
STDIAL:	xra	a		; reset error flag
	sta	ERRFLG		;
	call	PDISC		; on-hook
	call	HUKOFF		;
	call	PROFFH		; (possibly) print .off hook. message

; Wait routine will return with carry set if unable to get dialtone.
	mvi	d,DTMSK		;dial tone mask
	mvi	e,50		;waits up to 10 sec. for dial tone
	call	WAIT		;wait for dial tone
	rnc			;if dial tone within 10 seconds

	sta	ERRFLG		;(action on error deferred until 
	call	PDISC		;no tone, hang up
	ret			;   dialing is completed)


; End-dial sequence
ENDIAL:	call	ENDIT		;close out dialing
	push	psw		;
	xra	a		;
	sta	DIALFLG		;
	sta	ABOBYT		;
	pop	psw		;
	ora	a		;successfully connected?
	rz			;exit now if so
	push	psw		;nope, save the error code
	call	PDISC		;shut down the modem
	pop	psw		;
	ret			;


ENDIT:	lda	ERRFLG		;no-dialtone error from STDIAL?
	ora	a
	rnz			;if so, return the error here
	call	OFF		;go off-hook
	lda	UCTLB		;get uart/modem control byte
	call	oCTL1		;send it
	mvi	d,4		;clear-to-send mask
				;
	lda	WTNUM		;
	mov	e,a		;
	call	WAIT		;
	rnc			;return A=0 if good
				;
	cpi	'C'-40h		;keyboard abort?
	rz			;if so return it
				;
	if	CTRLX		;
	cpi	1		;Fake busy?
	rz			;Return if so
	endif			;CTRLX
				;
	mvi	a,2		;nope, convert error to "no answer"
	ret			;

;	<end of PMMI dialing routines>
;------------------------------------------------------------


;	Go Off-Hook
OFF:	lda	BAUDSV		;set current baud rate
	call	oBDRP		;
	lda	MODCTB		;Load current DTR
	call	oCTL2		;
	call	HUKOFF		;
	lda	UCTLB		;
	call	oCTL1		;
	mvi	b,2		;wait 200 ms	%%* changed from 1 to 2.
	call	TIMOUT		;	
	lda	DIALFLG		;
	ora	a		;
	jz	PRONLN		;
	xra	a		;
	sta	DIALFLG		;
PRWAIT:	lxi	h,PRXTRA	;
	lxi	d,WAITMSG	;
	jmp	PRMAYBE		;

PROFFH:	lxi	h,PRXTRA	;
	lxi	d,OFFHMSG	;
	jmp	PRMAYBE		;

PRONLN:	lxi	h,PRXTRA	;
	lxi	d,ONLNMSG	;
	jmp	PRMAYBE		;

OFFHMSG: db	'.off-h. $'	; Force PMMI to on-line status.
ONLNMSG: db	'.on-line. $'	; Force PMMI to on-line status.
WAITMSG: db	'.wait. $'	; Force PMMI to   "      " and wait
				;  for either a carrier or timeout.


HUKOFF:	mvi	a,255		; Go Off-Hook
	sta	OFFHK		;
	mvi	a,MAKEM		;
	jmp	oCTL1		;


HUKONN:	xra	a		; Go On-Hook
	sta	OFFHK		;
	mvi	a,BRKMASK	;
	jmp	oCTL1		;




; Time-out routine.  Must be called with mask in D reg. for input at
; relative port 2 and number of seconds (times 10) in E reg.
WAIT:	mvi	b,2		; 200 ms
	call	TIMOUT		; wait for timer to go high then low
	call	iBDRP		; pmmiaddr+2 (modem status port)
	ana	d		; (cts or dialtone mask)
	rz			; active low, so return on 0

	if	not CTRLX	;
	mvi	c,CHEKCC	;not yet, check for console-abort
	call	MEX		;abort?
	mvi	a,3		;set error code 3 if abort active
	stc			;
	rz			;return if aborted
	endif			;not CTRLX

	if	CTRLX		;
	lda	ABOBYT		;
	ora 	a		;
	jz	WAIT0		;
	push	psw		;
	xra	a		;
	sta	ABOBYT		;
	pop	psw		;
	jmp	WAIT1		;

WAIT0:	call	GET1C		;
	jz	WAITOR		;
				;
WAIT1:	cpi	CONTX		;'^X?'
	jnz	WAIT2		;no, check for ^C
	call	GET1C		;Clear out garbage
	mvi	a,1		;yes, return fake error code
	stc			;
	ret			;
WAIT2:	cpi	3		;Duplicate MEX ^C trap
	jnz	WAITOR		;Not ^C, continue
	call	GET1C		;Clear out garbage
	mvi	a,3		;"ABORT" error
	stc			;Yes, pass error 
	ret			;code and return
	endif			;CTRLX


WAITOR:	dcr	e		;
	jnz	WAIT		; nope, downcount
	inr	a		; set error=4 (modem error); cy already set
	ret			;


GET1C:	push	h
	push	d
	push	b
	mvi	c,6
	mvi	e,0FFh
	call	5
	pop	b
	pop	d
	pop	h
	ani	7Fh
	ret


PUT1C:	push	h
	push	d
	push	b
	mvi	c,6
	mov	e,a
	call	5
	pop	b
	pop	d
	pop	h
	ret


; Set baud-rate code in A (if supported by your modem overlay).  PMMI
; supports only five rates, which are validated here. NOTE: this routine
; (ie, the one vectored through NEWBDV) should update MSPEED with the
; passed code, but ONLY if that rate is supported by the hardware.
PBAUD:	push	h		;don't alter anybody
	push	d
	push	b
	mov	e,a		;code to DE
	mvi	d,0
	lxi	h,BAUDTB	;offset into table
	dad	d
	mov	a,m		;fetch code
	ora	a		;0? (means unsupported code)
	stc			;return error for STBAUD caller
	jz	PBEXIT		;exit if so
	call	oBDRP		;good rate, set it
	sta	BAUDSV		;save it
	mov	a,e		;get speed code back
	sta	MSPEED		;make it current
	call	GETDTR		;get correct DTR based on baud rate
	sta	MODCTB		;save the code
	call	CARRCK		;is a connection in progress?
	jnz	PBEXIT		;skip this if not
	lda	MODCTB		;yep, set up DTR
	call	oCTL2

PBEXIT:	lxi	h,PRXTRA
	lxi	d,BDSTMSG
	call	PRMAYBE
	pop	b		;all done
	pop	d
	pop	h
	ret

BDSTMSG: db	'.bd-rt. $'

; table of baud rate divisors for supported rates
BAUDTB:	db	142,052,035,026,022	;110,300,450,610,710
	db	0,0,0,0,0		;1200,2400,4800,9600,19200


; Sign-on message
SYSVER:	lxi	d,LINMSG
	mvi	c,PRINT
	call	MEX
	lxi	d,SOMESG
	mvi	c,PRINT
	call	MEX
	lxi	d,bpmess
	mvi	c,PRINT
	call	MEX
CARRSH:	lxi	d,NOMESG		;tell about carrier
	call	CARRCK			;check for it
	mvi	c,PRINT
	cz	CMSG
	cnz	MEX
	lxi	d,LINMSG
	mvi	c,PRINT
	call	MEX
	lxi	d,GRBMSG
	mvi	c,PRINT
	call	MEX
	ret
CMSG:	push	psw
	mvi	c,PRINT
	lxi	d,CARMSG
	call	MEX
	pop	psw
	ret


SOMESG: db	'* PMMI overlay version - '  
	db	REV/10+'0'
	db	'.'
	db	REV MOD 10+'0'
LEVEL:	db	'   *',CR,LF,'$'
BPMESS:	db	'* Base port = '
BPMSG:	db	'x0 hex.          *'
NLMSG:	db	cr,lf,'$'

NOMESG:	db	'* No carrier present.          *$'
CARMSG:	db	'* Carrier IS present.          *$'
LINMSG:	db	CR,LF,'********************************',CR,LF,'$'
GRBMSG:	db	CR,LF,'$'
;
;
; get DTR port value based on baud rate
;
GETDTR:	lda	BAUDSV
	cpi	52		;>300?
	mvi	a,05Fh		;set speed configuration (ARRRRRRGGGGHHHH.)
	rc			;done if so (Swapped in version 2.0)
	mvi	a,07Fh		;reset speed config bit (ARRRRRRGGGGGHHHH.)
	ret


; check the PMMI for carrier-present (NZ=no)
CARRCK:	call	iBDRP		;get status byte
	ani	CTSMSK
	rnz
	push	psw
	mvi	a,255
	sta	OFFHK
	pop	psw
	ret


; Newline on console
CRLF:	mvi	a,CR
	call	TYPE
	mvi	a,LF		;fall into TYPE


; type char in A on console
TYPE:	push	h		;save 'em
	push	d
	push	b
	mov	e,a		;align output character
	mvi	c,CONOUT	;print via MEX
	call	MEX
	pop	b
	pop	d
	pop	h
	ret


; strings to clear-to-end-of-screen, and clear-screen
; Note: these are dummy strings, not intended to be displayed...
EOSMSG:	db	' -clr eos- $'	;clear to end-of-screen
CLSMSG:	db	' -clr all- $'	;clear whole screen


;
;------------------------------------------------------------
;
; The remainder of this overlay implements a very versatile
; SET command -- if you prefer not to write a SET for your
; modem, you may delete the code from here to the END statement.
;
;
; Control is passed here after MEX parses a SET command.
;
SETCMD:	mvi	c,SBLANK	;any arguments?
	call	MEX
	jc	SETSHO		;if not, go print out values
	lxi	d,CMDTBL	;parse command
	call	TSRCH		;from table
	push	h		;any address on stack
	rnc			;if we have one, execute it
	pop	h		;nope, fix stack
SETERR:	lxi	d,SETEMS	;print error
	mvi	c,PRINT
	call	MEX
	ret
;
SETEMS:	db	CR,LF,'SET command error',CR,LF,'$'
;
; SET command table ... note that tables are constructed of command-
; name (terminated by high bit=1) followed by word-data-value returned
; in HL by MEX service processor LOOKUP.  Table must be terminated by
; a binary zero.
;
; Note that LOOKUP attempts to find the next item in the input stream
; in the table passed to it in HL ... if found, the table data item is
; returned in HL; if not found, LOOKUP returns carry set.
;
CMDTBL:	db	'?'+80h			; "set ?"
	dw	STHELP			;
	db	'BAU','D'+80h		; "set baud"
	dw	STBAUD			;
	db	'ID','D'+80h		; "set id"
	dw	SETIDD			;
	db	'ANSWE','R'+80h		; "set answer"
	dw	STANSW			;
	db	'AN','S'+80h		; "set ans" (same as above)
	dw	STANSW			;
	db	'ORIGINAT','E'+80h	; "set originate"
	dw	STORIG			;
	db	'ORI','G'+80h		; "set orig" (same as above)
	dw	STORIG			;
	db	'OR','G'+80h		; "set org" (same as above)
	dw	STORIG			;
	db	'OFFHOO','K'+80h	; "set offhook"
	dw	OFF			;
	db	'ONLIN','E'+80h		; "set online" (same as offhook)
	dw	OFF			;
	db	'ONHOO','K'+80h		; "set onhook"
	dw	PDISC			;
	db	'OFFLIN','E'+80h	; "set offline" (same as onhook)
	dw	PDISC			;
	db	'PP','S'+80h		; "set pps"
	dw	SETPPS			;
	db	'BAS','E'+80h		; "set PMMI base port."
	dw	SETBP			;
	db	'IC','D'+80h		; "set delay between calls"
	dw	SETICD			;
	db	'EXTR','A'+80h		; "set extra print mode"
	dw	SETXTRA			;
	db	'XYZZ','Y'+80h		;
	dw	XYZZY			;
					;
	db	0			; <<=== table terminator
;
; SET <no-args>: print current statistics
;
SETSHO:	call	SYSVER		;show carrier present/not present
	lxi	h,SHOTBL	;get table of SHOW subroutines
SETSLP:	mov	e,m		;get table address
	inx	h
	mov	d,m
	inx	h
	mov	a,d		;end of table?
	ora	e
	rz			;exit if so
	push	h		;save table pointer
	xchg			;adrs to HL
	call	GOHL		;do it
	call	CRLF		;print newline
	mvi	c,CHEKCC	;check for console abort
	call	MEX
	pop	h		;it's done
	jnz	SETSLP		;continue if no abort
	call	CRLF
	ret

GOHL:	pchl


; table of SHOW subroutines
SHOTBL:	dw	BDSHOW
	dw	MDSHOW
	dw	SHOICD
	dw	SHOIDD
	dw	SHOPPS
	dw	SHOXTRA
	dw	CRLF
	dw	0		;<<== table terminator

;
; SET ?  processor
;
STHELP:	lxi	d,HLPMSG
	mvi	c,PRINT
	call	MEX
	ret
;
; The help message
;
HLPMSG:	db	cr,lf,'SET command, for the PMMI S-100 modem (r.i.p.)'
	db	cr,lf
	db	cr,lf,'SET ANSWER <or> SET ANS     ... put PMMI in answer mode'
	db	cr,lf,'SET BASE <hex #>            ... set new PMMI base port'
	db	cr,lf,'SET BAUD <value>            ... set baud rate'
	db	cr,lf,'    BAUD values allowed are:    110, 300, 450, 600, and 710'
	db	cr,lf,'SET EXTRA <value>           ... OFF if <value> == 0, else ON'
	db	cr,lf,'    EXTRA function diagnostics displayed: BAUD RATE, BREAK,'
	db	cr,lf,'          DISCONNECT, OFF-HOOK, and WAIT (for answer tone)'
	db	cr,lf,'SET ICD <value>'
	db	      '             ... intercall delay; 150 == 30 seconds'
	db	cr,lf,'SET IDD <value>             ... interdigit delay in 100''s msec'
	db	cr,lf,'SET OFFHOOK <or> SET ONLINE ... force PMMI online'
	db	cr,lf,'SET ONHOOK <or> SET OFFHOOK ... disconnect without message'
	db	cr,lf,'SET ORIGINATE <or> SET ORIG ... put PMMI in originate mode'
	db	cr,lf,'SET PPS <value>             ... may be 10, 15 or 20 pulses/sec.'
	db	cr,lf
	db	cr,lf, '$'


; SET BAUD processor
STBAUD:	mvi	c,BDPARS	;function code
	call	MEX		;let MEX look up code
	jc	SETERR		;invalid code
	call	PBAUD		;no, try to set it
	jc	SETERR		;not-supported code
BDSHOW:	call	ILPRT		;display baud
	db	'Baud rate: ', tab, '   ', 0
	lda	MSPEED
	mvi	c,PRBAUD	;use MEX routine
	call	MEX
	ret


; SET MODE processor
MDSHOW:	call	ILPRT		;show mode
	db	'Mode:', tab, tab, '   ', 0
	lda	UCTLB		;get UART B image
	ani	ORBIT		;orig?
	jz	MDORIG
	call	ILPRT
	db	'Originate', 0
	ret

MDORIG:	call	ILPRT
	db	'Answer', 0
	ret

STORIG: mvi	l,ORBIT 
	jmp	CHGAO

STANSW: mvi	l,ANBIT
CHGAO:	lda	UCTLB
	ani	MODEMK
	ora	l
	sta	UCTLB
	call	OHKBYT
	jnz	MDSHOW
	call	oCTL1
	call	OFF
	jmp	MDSHOW

OHKBYT:	lda	OFFHK
	cma
	ora	a
	ret

;
; SET PPS command processor
;
SETPPS:	lxi	d,PPSTBL	;get value
	call	TSRCH
	jc	SETERR		;not found in table? error out
	mov	a,l		;yep, set it
	sta	PRATE
SHOPPS:	call	ILPRT
	db	'PPS rate: ', tab, '   ', 0
	lda	PRATE		;display PPS
	cpi	250
	jnz	SHO2
	call	ILPRT
	db	'10', 0
	ret
SHO2:	cpi	125
	jnz	SHO3
	call	ILPRT
	db	'20',0
	ret
SHO3:	call	ILPRT
	db	'15',0
	ret


PPSTBL:	db	'1','0'+80H	;"set pps 10"
	dw	250
	db	'1','5'+80h	;"set pps 15"
	dw	167
	db	'2','0'+80H	;"set pps 20"
	dw	125
	db	0		;<<=== table terminator
;
; SET IDIG command processor
;
SETIDD:	mvi	c,EVALA
	call	MEX		;get numeric
	mov	a,h		;validate
	ora	a
	jnz	SETERR
	mov	a,l
	sta	INTERD		;set new rate
SHOIDD:	call	ILPRT
	db	'Inter-digit delay: ', 0
	lda	INTERD		;get value
	mov	l,a		;move delay to HL
	mvi	h,0
	mvi	c,DECOUT	;print it
	call	MEX
	call	ILPRT
	db	'00 ms',0
	ret


; Set BASE PORT command processor.
SETBP:	mvi	c,SBLANK
	call	MEX
	mvi	c,GNC		;get char from input, cy=1 if none
	call	MEX
	call	UPPER
	mov	l,a		; Character to test is in L.
	shld	TEMP

	lxi	b,BPTAB-1
	lxi	d,10h
	lxi	h,-10h

SETLP:	inx	b		; Advance to next allowable character.
	dad	d		; Add 10 hex to base port address.
	ldax	b		;
	ora	a		;
	jm	SETNG		; Jump if character typed not in allowable set.
	push	h		;
	lhld	TEMP		;
	cmp	l		; Valid port requested?
	shld	TEMP		;
	pop	h		; Restore new base port.
	jnz	SETLP		; No match, try again.
	sta	BPMSG		; Patch sign-on message with Port # (ascii).
	mov	a,l		;
	sta	NITBYT		; Save base port (hex) for I/O and for CLONING.
	ret


BPNOGO:	db	7, '  ****  Invalid port  ****', cr, lf, '$'
SETNG:	lxi	d,BPNOGO
	mvi	c,PRINT
	jmp	MEX


SETICD:	mvi	c,EVALA
	call	MEX		;get numeric
	mov	a,h		;validate
	ora	a
	jnz	SETERR
	mov	a,l
	sta	WTNUM		;set new rate
SHOICD:	call	ILPRT
	db	'Inter-call delay:  ', 0
	lda	WTNUM		;get value
	mov	l,a		;move delay to HL
	mvi	h,0
	mvi	c,DECOUT	;print it
	call	MEX
	call	ILPRT
	db	' ticks. (150 ticks=30 seconds)', 0
	ret

SETXTRA: mvi	c,EVALA
	call	MEX
	mov	a,h
	ora	a
	jnz	SETERR
	mov	a,l
	sta	PRXTRA
SHOXTRA: call	ILPRT
	db	'Extra print mode:  ',0
	lda	PRXTRA
	ora	a
	lxi	d,ONNMSG
	jnz	SHOXT2
	lxi	d,OFFMSG
SHOXT2:	jmp	PRMBOK

ONNMSG:	db	'ON$'
OFFMSG:	db	'OFF$'


; Compare next input-stream item in table @DE; CY=1
; if not found, else HL=matched data item
TSRCH:	mvi	c,LOOKUP	;get function code
	jmp	MEX		;pass to MEX processor


XYZZY:	call ILPRT
	db	'Nothing happens...', 0
	ret


; Print in-line message
ILPRT:	mvi	c,ILP		;get function code
	jmp	MEX		;go do it


TIMOUT:	mvi	c,TIMER		;
	jmp	MEX		;


UPPER:	cpi	'a'
	rc
	cpi	'z'+1
	rnc
	sui	'a'-'A'
	ret


;------------------------------------------------------------
;
; End of PMMI MEX modem overlay
;
;------------------------------------------------------------


	end
