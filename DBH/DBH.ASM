.model tiny
.code
org 100h

FrameHeight	equ 7
FrameWidth	equ 21
FrameRow	equ 10
FrameCol	equ 39

FrameAttr	equ 4Fh
FrameShadow	equ 00001000b

FrameUpSta	equ 201
FrameUpMid 	equ 205
FrameUpEnd 	equ 187

FrameMiSta 	equ 186
FrameMiMid 	equ 255
FrameMiEnd 	equ 186

FrameEnSta 	equ 200
FrameEnMid 	equ 205
FrameEnEnd 	equ 188

ScreenFill	equ 07B2h
ScreenH 	equ 25
ScreenW 	equ 80
Message 	equ offset Msg

VramOffset 	equ 0B800h
MsgSize 	equ (2*(FrameWidth - 1) * 2*(FrameHeight - 1)) * 2
FNameSize	equ 40

save macro regs ;; save regs
	irp r, <regs>
		push r
	endm
endm

rest macro regs ;; restore regs
	irp r, <regs>
		pop r
	endm
endm

Start:
	; video mode
	mov 	bl, 01h
	mov 	bh, 00h
	mov 	ah, 00h
	mov 	al, 3
	int 	10h

	mov 	si, 82h
	call 	adjustString
	call 	readNumber
	save <bx> ; read number

	mov 	cx, 1
	mov 	di, offset numberBuffer
	call 	printNumber

	mov 	si, ScreenFill
	call	fillScreen
	
	mov 	al, FrameRow
	mov 	ah, FrameCol
	mov 	dl, FrameHeight
	mov 	dh, FrameWidth
	call	printEnlargingFrame

	modalW = 9
	modalH = 2
	int 3

	save <di> ; first modal
	;mov 	si, 1
	mov 	bl, modalH
	mov 	bh, modalW
	call 	printFrame
	save <di>
	mov 	dx, modalW * 2
	mov 	cx, modalH * 2 - 1
	mov 	si, 82h
	call	printStringVram
	rest <di>
	add 	di, ScreenW * 2
	mov 	si, offset decNote
	call 	printStringVram
	rest <di, bx>

	save <bx, di> ; second modal
	add 	di, (FrameWidth) * 2
	mov 	bl, modalH
	mov 	bh, modalW
	;mov 	si, 1
	call 	printFrame

	save <di>
	mov 	dx, modalW * 2
	mov 	cx, modalH * 2 - 1
	mov 	si, offset numberBuffer
	call	printStringVram
	rest <di>
	add 	di, ScreenW * 2
	mov 	si, offset binNote
	call 	printStringVram
	rest <di, bx>

	save <bx, di>
	mov 	cx, 3
	mov 	di, offset numberBuffer
	call 	printNumber
	rest <di, bx>

	save <bx, di> ; third modal
	add 	di, (FrameWidth) * 2 + (ScreenW) * 2 * (modalH * 2)
	mov 	bl, modalH
	mov 	bh, modalW
	;mov 	si, 1
	call 	printFrame
	save <di>
	mov 	dx, modalW * 2
	mov 	cx, modalH * 2 - 1
	mov 	si, offset numberBuffer
	call	printStringVram
	rest <di>
	add 	di, ScreenW * 2
	mov 	si, offset octNote
	call 	printStringVram
	rest <di, bx>

	save <bx, di>
	mov 	cx, 4
	mov 	di, offset numberBuffer
	call 	printNumber
	rest <di, bx>

	save <bx, di> ; forth modal
	add 	di, (FrameWidth) * 2 + (ScreenW) * 2 * (2 * (modalH * 2))
	mov 	bl, modalH
	mov 	bh, modalW
	;mov 	si, 1
	call 	printFrame
	save <di>
	mov 	dx, modalW * 2
	mov 	cx, modalH * 2 - 1
	mov 	si, offset numberBuffer
	call	printStringVram
	rest <di>
	add 	di, ScreenW * 2
	mov 	si, offset hexNote
	call 	printStringVram
	rest <di, bx>

	mov 	cx, 5Fh
	mov 	dx, 2240h
	call	sleep
	
	mov 	ax, 4c00h
	int 	21h

; Prints number to desired string
; in selected base (must be 2^power)
; ================
; bx - number
; cx - power
; di - string buffer
printNumber proc
	save <ax, bx, cx, di, dx>
	save <ax>
	xor 	dx, dx
	mov 	ax, 16
	div 	cx
	mov 	dx, ax
	rest <ax>
	charByChar:
		save <dx>
		mov 	ax, bx
		shl 	bx, cl
		call 	getUpperMask
		and 	ax, dx
		rol 	ax, cl

		cmp 	ax, 10
		jl  	setLetter
		add 	ax, 7
		setLetter:
		add	ax, '0'
		stosb
		rest <dx>
		dec 	dx
	cmp 	dx, 0
	jne 	charByChar
	mov 	ax, '$'
	stosb
	rest <dx, di, cx, bx, ax>
	ret
endp

; Mash of cx last bits
; ================
; cx - power
; ================
; dx - mask
getUpperMask proc
	xor 	dx, dx
	save <cx, bx>
	mov 	bx, 16
	sub 	bx, cx
	mov 	cx, bx
	getMaskLoop:
		shl 	dx, 1
		inc 	dx
	loop getMaskLoop
	not 	dx
	rest <bx, cx>
	ret
endp

; Sets '$' to the first encountered space
; or unprintable symbol
; ================
; si - string
; ================
; modifies memory
adjustString proc
	save <ax, si>
	adjustStringLoop:
		lodsb
		cmp 	al, ' '
		je  	adjustStringLoopEnd
		cmp  	al, '$'
		je  	adjustStringLoopEnd
		cmp  	al, 127
		jae  	adjustStringLoopEnd
		cmp 	al, 16
		jbe 	adjustStringLoopEnd
		je adjustStringLoopEnd

	jmp adjustStringLoop
	adjustStringLoopEnd:
	mov 	[si - 1], '$'
	rest <si, ax>
	ret
endp

; Read number from $-terminated string
; ================
; si - string
; ================
; bx -  number
readNumber proc
	save <si, ax, dx, cx>
	xor 	bx, bx
	xor	ax, ax
	mov 	cx, 10
	readNumberLoop:
		lodsb
		cmp 	ax, '$'
		je  	readNumberLoopEnd
		
		save <ax>
		mov 	ax, bx
		mul 	cx
		mov 	bx, ax
		rest <ax>
		
		sub 	ax, '0'
		add 	bx, ax
	jmp 	readNumberLoop
	readNumberLoopEnd:
	rest <cx, dx, ax, si>
	ret
endp

; Get file content
; ================
; dx filename
; cx number of bytes to read
; di data destination
retrieveFile proc
	save <ax, bx, cx, dx, si, di, es>

	mov 	ah, 3Dh	; open file and get handle
	xor 	al, al	; read only
	int 	21h
	jnc	retrieveFileSuccess

	; copy error msg a file content
	mov 	si, offset errFileReadMsg
	mov 	bx, ds
	mov 	es, bx	; es = ds
	rep 	movsb

	jmp 	retrieveFileReturn
	retrieveFileSuccess:
	mov 	dx, di	; destination
	mov 	bx, ax	; handle
	mov 	ah, 3Fh
	int 	21h

	retrieveFileReturn:
	rest <es, di, si, dx, cx, bx, ax>
	ret
endp

; Transfer filename form c. args to ascii
; zero-terminated
; ================
; si source
; di destination
ASCIIFname proc
	save <ax, di, si, es>
	mov 	ax, ds
	mov 	es, ax	; es = ds

	fileNameLoop:
		lodsb
		; end if unprintable or special 
		cmp 	al, ' '
		je  	fnameEnd
		cmp  	al, '$'
		je  	fnameEnd
		cmp  	al, 127
		jae  	fnameEnd
		cmp 	al, 16
		jbe 	fnameEnd
		stosb
	jmp fileNameLoop
	fnameEnd:

	xor 	ax, ax ; zero - terminated
	stosb
	rest <es, si, di, ax>
	ret
endp

; Print string to vram
; ================
; si for string (ends with $)
; di for start vram pos
; dx for max line length
; cx for max lines
printStringVram proc	
	save <ax, bx, dx, cx, si, es>
	add	dx, dx
	sub	dx, 4

	mov 	bx, VramOffset
	mov 	es, bx
	mov 	bx, di ; bx = current line start

	printVramLoop:
		xor 	ax, ax
		lodsb

		; exit if met $
		cmp 	ax, '$'
		je  	printVramLoopEnd
		
		checknlSymbol:
		cmp 	ax, 13
		jne 	nlSymbol
		add 	bx, ScreenW * 2
		mov 	di, bx	; next line select
		dec 	cx	; one line less left 
		inc	si
		lodsb
		jmp 	checknlSymbol
		nlSymbol:

		cmp	ax, 31
		ja	visibleSym
		mov	ax, 255
		visibleSym:
		
		save <cx>
		mov 	cx, di
		sub 	cx, bx

		cmp 	cx, dx
		jb  	noNewLineMax
		add 	bx, ScreenW * 2
		mov 	di, bx

		rest <cx>
		dec 	cx
		save <cx>
		noNewLineMax:

		rest <cx>
		cmp	cx, 1
		jbe	printVramLoopEnd
		stosb
		inc 	di	; skip attribute
	jmp printVramLoop
	printVramLoopEnd:
	
	rest <es, si, cx, dx, bx, ax>
	ret
endp

; Displays enlarging frame
; ================
; al for row coordinate of center
; ah for col coordinate of center
; dl for half height 
; dh for half width
; ================
; di position inside frame
printEnlargingFrame proc	
	save <si, bx, cx>

	mov 	si, 1

	xor 	bx, bx	; bx is current dims
	xor 	cx, cx
	mov 	cl, dh	; cx = call width

	; cx = max(cx, dh)
	save <dx>
	xor 	dh, dh
	cmp 	dx, cx
	jb  	changeMax
	mov 	cl, dl
	changeMax:
	rest <dx>

	; cx - looped
	enlargingLoop:
		save <cx>

		xor 	cx, cx
		mov 	cl, bl	; cx is current height

		save <dx>
		xor 	dh, dh	; dx is desired height
		; increase height if needed
		cmp 	dx, cx
		jbe 	noHeightEnl
		inc 	cx
		mov 	bl, cl
		noHeightEnl:
		rest <dx>
		
		xor 	cx, cx
		mov 	cl, bh	; cx is current width

		save <dx>
		mov 	dl, dh
		xor 	dh, dh	; dh is desired width
		; increase width if needed
		cmp 	dx, cx
		jbe 	noWidthtEnl
		inc 	cx
		mov 	bh, cl
		noWidthtEnl:
		rest <dx>

		call 	printCenterFrame

		save <cx, dx>
		mov 	cx, 03h
		mov 	dx, 4240h
		call	sleep
		rest <dx, cx>

		rest <cx>
	loop		enlargingLoop
	rest <cx, bx, si>
	ret
endp

; Sleep for seconds:miliseconds
; ================
; cx:dx for desired time
sleep proc
	save <ax>
	mov	ah, 86h
	int	15h
	rest <ax>
	ret
endp

; Displays frame
; ================
; al for row coordinate of center
; ah for col coordinate of center
; bl for half height 
; bh for half width
; si = 1 -> shadow
; ================
; di position inside frame
printCenterFrame proc
	save <bx>
	sub 	bx, 0101h ; sub borders
	call 	doubleHW ; -> bl, bh
	call 	calcStartXY ; -> di
	rest <bx>
	call 	printFrame
	ret
endp

; Displays frame
; ================
; di for start position
; bl for half height 
; bh for half width
; si = 1 -> shadow
; ================
; di position inside frame
printFrame proc
	save <es, ax, bx, cx, dx>
	save <di>
	sub 	bx, 0101h ; sub borders
	save <ax>
	mov 	ax, VramOffset
	mov 	es, ax
	rest <ax>
	
	call doubleHW ; -> bl, bh
	rest <di>
	save <di>

	save <ax>
	mov 	al, bh
	xor 	ah, ah
	mov 	dx, ax	; dx = row length
	rest <ax>
	
	save <bx>
	mov 	al, FrameUpSta	; left symbol
	mov 	ah, FrameUpEnd	; right symbol
	mov 	bl, FrameUpMid	; middle symbol
	mov 	bh, FrameAttr	; common attribute
	mov 	cx, dx 	; row length
	call	printFrameRow
	rest <bx>

	mov 	cl, bl	; rows number
	mov 	ch, 0
	mov 	al, FrameMiSta	; left symbol
	mov 	ah, FrameMiEnd	; right symbol
	mov 	bl, FrameMiMid	; middle symbol
	mov 	bh, FrameAttr
	
	inc 	cx	; cx - iterated
	frameRows:
		save <cx>
		mov 	cx, dx
		add 	di, ScreenW * 2		
		call 	printFrameRow

		cmp 	si, 1
		jne 	noShadow
		save <di, ax> ; if shadow enabled
		add 	di, dx
		add 	di, dx
		add 	di, 2 * 2 + 1
		mov 	al, FrameShadow
		stosb
		rest <ax, di>
		noShadow:
		rest <cx>
	loop 	frameRows

	mov		al, FrameEnSta
	mov		ah, FrameEnEnd
	mov		bl, FrameEnMid
	mov 	cx, dx	; length
	call	printFrameRow

	; bottom shadow
	cmp 	si, 1
	jne 	noShadow2
	add 	di, ScreenW * 2 + 2 * 2 + 1
	push 	cx
	mov 	cx, dx
	inc 	cx
	mov 	al, FrameShadow
	loopBottom:
		stosb
		inc 	di
	loop	loopBottom
	pop 	cx
	noShadow2:
	pop 	di

	; inside frame pos
	add 	di, ScreenW * 2 + 2
	rest <dx, cx, bx, ax, es>
	ret
endp

; Doubles height and width
; ================
; bl for half height 
; bh for half width
; ================
; bl for height 
; bh for width
doubleHW proc
	save <ax, cx>
	xor 	ax, ax
	mov 	al, bl	; ax = half height
	add 	ax, ax	; ax = height
	mov 	bl, al	; bl = height

	xor 	ax, ax
	mov 	al, bh	; ax = half width
	add 	ax, ax	; ax = width
	mov 	bh, al	; bh = width
	rest <cx, ax>
	ret
endp

; Calculates position of
; left upper corner
; ================
; al for row coordinate of center
; ah for col coordinate of center
; bl for height 
; bh for width
; ================
; di position of left upper corner
calcStartXY proc
	save <ax, bx, dx>
	xor 	ah, ah	; ax = row coordinate
	add 	ax, ax	; ax = row * 2

	xor 	bh, bh	; bx = half height
	sub 	ax, bx	; ax = row * 2 - h

	mov 	bx, ScreenW
	mul 	bx 	; ax = 80 * (row * 2 - h)

	mov 	bx, sp
	mov 	di, ax

	mov 	ax, [bx + 4]	; ax restored
	mov 	al, ah	
	xor 	ah, ah
	add 	ax, ax ; ax = col * 2

	mov 	dx, [bx + 2]	; bx restored
	mov 	dl, dh 
	xor 	dh, dh	; dx = width
	sub 	ax, dx
	add 	di, ax
	; di = 80 * (row * 2 - h) + col * 2 - w	
	rest <dx, bx, ax>
	ret
endp

; Displays frame one row
; ================
; al for start symbol
; ah for end symbol
; bl for middle symbol
; bh for common attribute
; cx for length
; di for start position
printFrameRow proc	
	save <si, es, di>

	save <ax>
	mov 	ax, VramOffset
	mov 	es, ax
	rest <ax>

	; first pixel
	save <ax>
	mov 	ah, bh
	stosw
	rest <ax>

	; middle pixels
	save <ax, cx>
	mov 	ax, bx
	repe 	stosw
	rest <cx, ax>
	
	; last pixel
	save <ax>
	mov     al, ah
	mov     ah, bh
	stosw
	rest <ax>

	rest <di, es, si>
	ret
endp

; Fill screen with one symbol
; ================
; si for symbol
fillScreen proc
	save <cx, ax, es, di>

	xor 	di, di
	mov 	cx, ScreenW * ScreenH
	mov 	ax, VramOffset
	mov 	es, ax
	mov 	ax, si
	repe stosw

	rest <di, es, ax, cx>
	ret
endp

Msg 		db MsgSize DUP(0), '$'
fileName	db FNameSize DUP(0), '$'
numberBuffer	db 16 DUP(0), '$'
errFileReadMsg	db 'Cannot open the file', '$'

decNote 	db 'decimal', '$'
hexNote 	db 'hexadecimal', '$'
octNote 	db 'octal', '$'
binNote 	db 'binary', '$'

End 	Start
