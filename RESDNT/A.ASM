.286
.model tiny
.code
org 100h

IntNumber	equ 8
IntKeyboard	equ 9
ScanCodeHK	equ 2Bh

FrameHeight	equ 6
FrameWidth	equ 5
FrameRow	equ 5
FrameCol	equ 0

FrameAttr	equ 4Fh
FrameShadow	equ 00001000b

FrameUpSta	equ 205
FrameUpMid 	equ 205
FrameUpEnd 	equ 187

FrameMiSta 	equ 255
FrameMiMid 	equ 255
FrameMiEnd 	equ 186

FrameEnSta 	equ 205
FrameEnMid 	equ 205
FrameEnEnd 	equ 188

ScreenH 	equ 25
ScreenW 	equ 80

VramOffset 	equ 0B800h

save macro regs
	;; save regs
	irp r, <regs>
		push r
	endm
endm

rest macro regs 
	;; restore regs
	irp r, <regs>
		pop r
	endm
endm

printNumberMacro macro reg, lbl
	add 	di, ScreenW * 2
	save <cx, bx>
	mov 	bx, reg
	mov 	cx, offset lbl
	call 	printLabeledNum
	rest <bx, cx>	
endm 

Start:
	mov 	di, offset Handler
	mov 	bx, IntNumber
	mov 	ax, offset OldIntAdr
	call 	intSet

	mov 	di, offset HandlerKeyboard
	mov 	bx, IntKeyboard
	mov 	ax, offset OldKbdAdr
	call 	intSet

	
	mov 	ax, 3100h
	mov 	dx, offset CODEOFFST
	shr 	dx, 4
	inc 	dx	
	int 	21h

Handler:
	pusha
	save <ds, bx>
	mov 	bl, byte ptr cs:[offset activated]	
	and 	bl, 1
	cmp 	bl, 1
	jne	HandlerEndBridge

	mov 	bx, cs
	mov 	ds, bx
	
	rest <bx>
	save <bx>	
	
	save <di>
	save <dx, si, bx>
	mov 	di, (FrameRow * ScreenW + FrameCol) * 2
	mov 	bl, FrameHeight
	mov 	bh, FrameWidth
	mov 	si, 0
	call 	printFrame
	rest <bx, si, dx>

	sub 	di, ScreenW * 2
	printNumberMacro ax, axStr
	printNumberMacro bx, bxStr
	printNumberMacro cx, cxStr
	printNumberMacro dx, dxStr 

	jmp	BridgeBorder
	HandlerEndBridge:
	jmp 	HandlerEnd
	BridgeBorder:	

	printNumberMacro si, siStr	
	printNumberMacro ss, ssStr
	printNumberMacro es, esStr
	printNumberMacro bp, bpStr

	add 	di, ScreenW * 2
	save <cx, bx>
	mov 	bx, sp
	mov 	bx, ss:[bx + 4]	; di
	mov 	cx, offset diStr
	call	printLabeledNum
	rest <bx, cx>

	add 	di, ScreenW * 2
	save <cx, bx>
	mov 	bx, sp
	mov 	bx, ss:[bx + 8]	; ds
	mov 	cx, offset dsStr
	call 	printLabeledNum
	rest <bx, cx>

	rest <di>
	HandlerEnd:	
	rest <bx, ds>
	popa
db 0EAh
OldIntAdr	dw 0, 0

HandlerKeyboard:
	save <si, di, es, ax, bx, cx, dx, ss, ds>	
	mov 	bx, cs
	mov 	ds, bx

	mov 	di, VramOffset
	mov 	es, di
	
	mov 	ax, 4ch
	in  	al, 60h

	cmp 	al, ScanCodeHK
	jne	HandlerKeyboardEnd
	mov 	bl, byte ptr [offset activated]
	and 	bl, 1
	not 	bl
	mov 	byte ptr [offset activated], bl
	HandlerKeyboardEnd:
	rest <ds, ss, dx, cx, bx, ax, es, di, si>
db 0EAh
OldKbdAdr	dw 0, 0

; Set interupt to new
; ================
; di - handler address
; bx - int number
; ax - far ret bytes
; ================
; Contamination:
; bx, ax, cx
intSet proc
	save <es>
	save <bx>
	mov 	bx, 0
	mov 	es, bx
	rest <bx>
	shl 	bx, 2
	mov 	cx, es:[bx]
	save <bx>
	mov 	bx, ax
	mov 	[bx], cx
	rest <bx>
	save <bx>
	mov 	cx, es:[bx + 2]
	mov 	bx, ax
	mov 	[bx + 2], cx
	rest <bx>

	cli
	mov 	es:[bx], di
	mov 	es:[bx + 2], cs
	sti
	rest <es>
endp 

; Prints label and number in hex
; ================
; bx - number
; cx - label adress
; di - start vram pos
; ================
; Contamination:
; cx
printLabeledNum proc
	save <si, dx, di>
	save <cx, di>
	mov 	cx, 4
	mov 	di, offset numberBuffer
	call 	printNumber
	rest <di, cx>
	mov 	si, cx
	mov 	dx, 0FFFEh
	mov 	cx, 0FFFEh
	call 	printStringVram
	mov 	si, offset numberBuffer
	call 	printStringVram
	rest <di, dx, si>
	ret
endp


; Prints number to desired string
; in selected base (must be 2^power)
; ================
; bx - number
; cx - power
; di - string buffer
printNumber proc
	save <es, ax, bx, cx, di, dx, si>
	save <ax>
	mov 	ax, ds
	mov 	es, ax

	mov 	ax, cx
	and 	ax, 1
	xor 	si, si

	cmp 	ax, 1
	jne evenPrint
	mov 	ax, bx
	and 	ax, 8000h
	cmp 	ax, 8000h
	jne	noOverflowInPrnt 	
	mov 	ax, '1'
	stosb
	noOverflowInPrnt:
	shl 	bx, 1
	evenPrint:
	rest <ax>
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
	rest <si, dx, di, cx, bx, ax, es>
	ret
endp

; Mash of cx last bits
; ================
; cx - power
; ================
; dx - mask
getUpperMask proc
	mov 	dx, 0FFFFh
	shr 	dx, cl
	not 	dx
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

numberBuffer	db 20 DUP(0), '$'
activated	db 0
axStr		db "ax: ", '$'
bxStr		db "bx: ", '$'
cxStr		db "cx: ", '$'
dxStr 		db "dx: ", '$'
diStr	 	db "di: ", '$'
siStr 		db "si: ", '$'
dsStr		db "ds: ", '$'
esStr		db "es: ", '$'
ssStr		db "ss: ", '$'
bpStr		db "bp: ", '$'
; rdntVram	db DUP(0), '$'

CODEOFFST:
End	Start	
