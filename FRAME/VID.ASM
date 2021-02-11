.model tiny
.code
org 100h

FrameHeight	equ 7
FrameWidth	equ 16
FrameRow	equ 10
FrameCol	equ 39

FrameAttr	equ 1Fh
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
	mov 	bl, 01h
	mov 	bh, 00h
	mov 	ah, 00h
	mov 	al, 3
	int 	10h
 
	mov 	si, ScreenFill
	call	fillScreen
	
	mov 	al, FrameRow
	mov 	ah, FrameCol
	mov 	dl, FrameHeight
	mov 	dh, FrameWidth
	call	printEnlargingFrame
	
	push 	di
	mov 	si, 82h
	mov 	di, offset fileName
	call	ASCIIFname

	mov 	dx, di
	mov 	cx, MsgSize - 2
	mov 	di, Message
	call 	retrieveFile
	pop 	di

	mov 	dx, FrameWidth * 2
	mov 	si, Message
	mov 	cx, FrameHeight * 2 - 1
	call	printStringVram

	mov 	cx, 5Fh
	mov 	dx, 2240h
	call	sleep
	
	mov 	ax, 4c00h
	int 	21h

; Get file content
; ================
; dx filename
; cx number of bytes to read
; di data destination
retrieveFile proc
	save <ax, bx, cx, dx, si, di, es>

	mov 	ah, 3Dh
	xor 	al, al
	int 	21h
	jnc	retrieveFileSuccess

	mov 	si, offset errFileReadMsg
	mov	bx, ds
	mov 	es, bx
	rep 	movsb
	jmp 	retrieveFileReturn

	retrieveFileSuccess:
	mov 	dx, di
	mov 	bx, ax
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
	mov 	es, ax

	fileNameLoop:

	lodsb
	cmp al, ' '
	je fnameEnd
	cmp al, '$'
	je fnameEnd
	cmp al, 127
	jae fnameEnd
	cmp al, 16
	jbe fnameEnd

	stosb
	jmp fileNameLoop
	fnameEnd:

	xor 	ax, ax
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

	mov 	ax, di ; ax -> line start
	mov 	bx, VramOffset
	mov 	es, bx

	printVramLoop:
	xor 	bx, bx
	mov 	bl, byte ptr [si]
	cmp 	bx, '$'
	je  	printVramLoopEnd
	
	checknlSymbol:
	cmp	bx, 13
	jne	nlSymbol
	add	ax, ScreenW * 2
	mov	di, ax
	add	si, 2
	dec	cx
	mov	bl, byte ptr [si]
	jmp checknlSymbol
	nlSymbol:

	checkNLAgain:
	mov	bx, [si]
	cmp	bx, 'n\'
	jne  	noNewLine
	add 	ax, ScreenW * 2
	dec	cx
	mov	di, ax
	add	si, 2
	mov	bx, [si]
	jmp	checkNLAgain
	noNewLine:
	xor	bh, bh

	cmp	bx, 31
	ja	visibleSym
	mov	bx, 255
	visibleSym:
	
	save <cx>
	mov 	cx, di
	sub 	cx, ax

	cmp 	cx, dx
	jb  	noNewLineMax
	add 	ax, ScreenW * 2

	rest <cx>
	dec 	cx
	save <cx>

	mov 	di, ax
	noNewLineMax:

	rest <cx>
	cmp	cx, 1
	jbe	printVramLoopEnd

	mov 	es:[di], bl
	
	add 	di, 2
	inc 	si

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
printEnlargingFrame proc	
	save <si, bx, cx>

	mov 	si, 1

	xor	bx, bx	; bx is current dims
	xor	cx, cx
	mov	cl, dh

	push	dx
	xor	dh, dh
	cmp	dx, cx
	jb	changeMax
	mov	cl, dl
	changeMax:
	pop	dx
	enlargingLoop:
		push	cx
		xor 	cx, cx
		mov 	cl, bl	; cx is current height
		push	dx
		xor 	dh, dh	; dx is desired height
		cmp 	dx, cx
		jbe 	noHeightEnl
		inc 	cx
		mov 	bl, cl
		noHeightEnl:
		pop 	dx
		
		xor 	cx, cx
		mov 	cl, bh
		push	dx
		mov 	dl, dh
		xor 	dh, dh
		cmp 	dx, cx

		jbe 	noWidthtEnl
		inc 	cx
		mov 	bh, cl
		noWidthtEnl:

		pop 	dx
		call 	printFrame
		save <cx, dx>
		mov 	cx, 03h
		mov 	dx, 4240h
		call	sleep
		rest <dx, cx, cx>
		
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
printFrame proc
	save <ax, bx, cx, dx, ax, cx>

	sub	bx, 0101h
	mov	ax, 0
	mov	al, bl
	add 	ax, ax
	mov	bl, al

	mov	ax, 0
	mov	al, bh
	add 	ax, ax
	mov	bh, al	

	rest <cx, ax>
	save <ax, bx, dx>
	mov	ah, 0

	add 	ax, ax; row * 2

	mov	bh, 0
	sub	ax, bx

	mov	bx, ScreenW
	mul	bx
	; ax = 80 * (row * 2 - h)

	mov	bx, sp
	mov	di, ax
	mov	ax, [bx + 4]

	mov	al, ah
	mov	ah, 0
	add 	ax, ax

	mov	dx, [bx+2]
	mov	dl, dh
	mov	dh, 0
	sub	ax, dx
	add	di, ax
	; di = 80 * (row * 2 - h) + col * 2 - w	

	rest <dx, bx, ax>
	save <di, ax>

	mov 	al, bh
	mov 	ah, 0
	mov 	dx, ax
	rest <ax>

	save <bx>
	mov 	al, FrameUpSta	; left symbol
	mov 	ah, FrameUpEnd	; right symbol
	mov 	bl, FrameUpMid	; middle symbol
	mov 	bh, FrameAttr	; common attribute
	mov 	cx, dx
	call	printFrameRow
	rest <bx>

	mov	cl, bl
	mov	ch, 0
	mov	al, FrameMiSta	; left symbol
	mov	ah, FrameMiEnd	; right symbol
	mov	bl, FrameMiMid	; middle symbol
	mov	bh, FrameAttr
	inc	cx	
	frameRows:
		save <cx>
		mov	cx, dx
		add	di, ScreenW * 2		
		call 	printFrameRow
		cmp	si, 1
		jne	noShadow
			save <di, ax>
			add	di, dx
			add	di, dx
			add	di, 2 * 2
			mov 	al, FrameShadow
			call	putAttr
			rest <ax, di>
		noShadow:
		rest <cx>
		loop 	frameRows

	mov		al, FrameEnSta
	mov		ah, FrameEnEnd
	mov		bl, FrameEnMid
	mov 	cx, dx
	call	printFrameRow

	cmp 	si, 1
	jne 	noShadow2
	add	di, ScreenW * 2 + 2 * 2
	push 	cx
	mov 	cx, dx
	inc 	cx
	loopBottom:
		mov 	al, FrameShadow
		call	putAttr
		add 	di, 2
	loop	loopBottom
	pop 	cx
	noShadow2:
	pop 	di
	add 	di, ScreenW * 2 + 2

	rest <dx, cx, bx, ax>
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
	save <si, ax>
	mov 	ah, bh
	mov 	si, ax
	call 	putPix
	rest <ax>

	mov 	si, bx

	save <dx, cx, di, ax>

	mov 	ax, 2
	mul 	cx
	mov 	cx, ax
	mov 	dx, di
	add 	cx, di
	rest <ax>
		
	frameLoop:
		add 	dx, 2
		mov 	di, dx
		call 	putPix
		cmp 	cx, dx
		jg  	frameLoop
    	add 	di, 2
	save <ax>
	mov     al, ah
	mov     ah, bh
	mov     si, ax
	call    putPix

	rest <ax, di, cx, dx, si>
	ret
endp

; Put pixel to VRAM
; ================
; si for symbol
; di for destination
putPix proc
	save <di, ax, es>
    mov 	ax, VramOffset
    mov 	es, ax
	mov 	ax, si
	stosw
	rest <es, ax, di>
	ret
endp

; Changes attr of symbol in VRAM
; ================
; al for attribute
; di for destination symbol
putAttr proc
	save <bx, es, di>
	mov 	bx, VramOffset
	mov 	es, bx
	inc 	di
	stosb
	rest <di, es, bx>
	ret
endp

; Fill screen with one symbol
; ================
; si for symbol
fillScreen proc
	save <cx, ax, es, di>

	mov 	di, 0
	mov 	cx, ScreenW * ScreenH
	mov 	ax, VramOffset
	mov 	es, ax
	mov 	ax, si
	fillingLoop:
    	stosw
	loop	fillingLoop

	rest <di, es, ax, cx>
	ret
endp

Msg 		db MsgSize DUP(0), '$'
fileName	db FNameSize DUP(0)
errFileReadMsg db 'Cannot open the file', '$'

End 	Start
