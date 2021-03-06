; =================================================================
;	                System V calling convention
; =================================================================
; |	 		edi  esi  edx  ecx  r8d  r9d | stack -->
; |  		 1    2    3    4    5    6    7     ...
; | 64bit:	rdi  rsi  rdx  rcx  r8   r9
; | 		r10 - function's static chain pointer
; |
; |  		Floating point:
; |  		xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7 | stack -->
; |  		 1    2    3    4    5    6    7    8     9     ...
; |
; |         Clean-up: Caller
; |			Must preserve: rsp, rbp, rbx, r12 - r15
; |
; |			128 bytes stack zone is red-zonne
; |
; |			Can be used: rax, 1st return register
; |						 rdx, 2nd return register
; | 					 r11, tmp reg
; =================================================================
%define ArgNo(n) n * 8 + 16
IntSize 	equ 32
ByteSize 	equ 8

global    _main
extern    _sum
global    _myprintf
global    _sumWrapper


section   .text
formatError 	db 10, "Wrong format string!", 10, 0
formatErrorLen  equ $ - formatError
; o    x   d   c    s   b   %
; 111 120 100  99  115  98  37
; 98 - 120
printfJmpTable:
				 dq printf.printBinary ; b
				 dq printf.printChar   ; c
				 dq printf.printDecimal; d
		times 10 dq printf.formatError
				 dq printf.printOctal  ; o
		times 3  dq printf.formatError
			     dq printf.printString ; s
		times 4  dq printf.formatError
				 dq printf.printHex    ; x


section   .bss
numberBuffer	resb 33


section   .text

; Sum System V wrapper
; ================
_sumWrapper:
	enter 0, 0
	call	_sum
	leave
	ret
	

; Printf System V wrapper
; ================
_myprintf:
	enter 0,0
	mov 	r11, rbx
	mov 	r10, rcx ; save to further restore
	
	push rsi
	mov 	rsi, rdi
	mov 	rbx, '%'
	call 	countChar
	pop  rsi
	
	sub 	rcx, 6
	test 	rcx, rcx
	js 	.stackPushed ; pushing to the stack from the end
	mov 	rbx, rbp
	add 	rbx, 16
	shl		rcx, 3
	add 	rbx, rcx
	shr		rcx, 3
	inc 	rcx
	.loop:
		mov 	rax, [rbx]
		sub		rbx, 8
		push 	rax
	loop .loop
	.stackPushed:

	mov 	rcx, r10 ; restore rcx

	; System V pushes
	push 	r9
	push 	r8
	push 	rcx
	push 	rdx
	push 	rsi
	push 	rdi
	call printf
	mov 	rbx, r11
	leave
	ret

; Prints formatted string to console
; cdecl call convention
; %c - char
; %s - zero-terminated string
; %d - unsigned decimal
; %o - unsigned octal
; %x - unsigned hex
; %b - unsigned binary
; All other symbols are printed directly
; ================
; Contaminated: r9, r8, rdi, rsi, rcx, rax
; ================
printf:
	BufferSize equ 256
	enter BufferSize, 0
	push 	rbx

	; Print number using printNumber()
	%macro numberWrite 2
		push rax
		push rcx
		push rdi
		
		mov 	rbx, [rbp + ArgNo(rcx)]
		mov 	ecx, %2
		mov 	rdi, numberBuffer
		call 	printNumber
		mov 	rsi, rdi
		pop  rdi
		push rdi
		call 	bufferManageStr
		
		pop  rdi
		pop  rcx
		pop  rax
		jmp 	.processFurtherArg
	%endmacro

	mov     r9, BufferSize		  ; max buffer size
	xor 	r8, r8 			      ; current buffer size
	lea 	rdi, [rsp] 		      ; buffer
	mov 	rsi, [rbp + ArgNo(0)] ; format string
	mov 	rcx, 1				  ; current argument


	.loop:
		lodsb
		cmp 	al, 0
		je 		.loopEnd
		push 	rsi
		cmp 	al, '%'
		jne 	.simplePrint

		xor 	rax, rax
		pop 	rsi
		lodsb
		push 	rsi
		cmp 	al, '%'
		jl 		.formatError
		cmp 	al, '%'
		je 		.simplePrint
		cmp 	al, 'x'
		jg 		.formatError
		mov 	rbx, printfJmpTable - 8 * 'b'
		jmp		[rax * 8 + rbx]
		
		
		.printString:
		mov 	rsi, [rbp + ArgNo(rcx)]
		push 	rcx
		call 	bufferManageStr
		pop 	rcx
		jmp 	.processFurtherArg

		.printChar:
		mov  	rax, [rbp + ArgNo(rcx)]
		call 	bufferManage
		jmp 	.processFurtherArg

		.printDecimal:
		push rax
		push rdi
		push rcx
		push rdx
		push 	rdi
		mov 	eax, [rbp + ArgNo(rcx)]
		mov 	rdi, numberBuffer
		call 	printDecimalNumber
		pop 	rdi
		mov 	rsi, numberBuffer
		call 	bufferManageStr
		pop  rdx
		pop  rcx
		pop  rdi
		pop  rax
		jmp 	.processFurtherArg

		.printBinary:
		numberWrite 'b', 1
		.printOctal:
		numberWrite 'o', 3
		.printHex:
		numberWrite 'x', 4
		
		.formatError:
		mov		rdi, formatError
		mov		r8, formatErrorLen
		pop 	rsi
		jmp 	.loopEnd

		.simplePrint:
		call 	bufferManage
		pop 	rsi
		jmp 	.processFurther
		.processFurtherArg:
		pop 	rsi
		inc 	rcx
		.processFurther:
		
	jmp .loop
	.loopEnd:
	mov		rax, 0x02000004
	mov		rsi, rdi
	mov		rdi, 1
	mov		rdx, r8
	syscall
	pop 	rbx
	leave
	ret



; Add string to buffer or dump it
; and set new len
; ================
; rsi - string ptr
; rdi - buffer ptr
; r8  - buffer size
; r9  - max size
; ================
; r8  - new size
bufferManageStr:
	push 	rax
	.loop:
		lodsb
		cmp 	al, 0
		je 		.loopEnd
		call 	bufferManage
	jmp .loop
	.loopEnd:
	pop 	rax
	ret


; Add to buffer or dump it
; and set len = 0 + 1 (new byte)
; ================
; al  - new byte
; rdi - buffer ptr
; r8  - buffer size
; r9  - max size
; ================
; r8  - new size
bufferManage:
	cmp 	r8, r9
	jb	 	.processAdd

	push rcx
	push rax
	push rdi
	push rsi
	push rdx
	mov		rax, 0x02000004
	mov		rsi, rdi
	mov		rdi, 1
	mov		rdx, r8
	syscall
	xor 	r8, r8
	pop rdx
	pop rsi
	pop rdi
	pop rax
	pop rcx
	.processAdd:
	mov 	byte [rdi + r8], al
	inc 	r8
	ret


; Calculate string len
; ================
; rsi - string ptr
; ================
; rdx - len
; ================
strlen:
	push rax
	push rsi
	xor 	rdx, rdx
	.loop:
		lodsb
		cmp		al, 0
		je		.loopEnd
		inc 	rdx
	jmp 	.loop
	.loopEnd:
	pop  rsi
	pop  rax
	ret
	


; Prints number to desired string
; in selected base (must be 2^power)
; ================
; (c) ebx - number
; ecx - power
; (c) rdi - string buffer
; ================
; Contaminated: ebx, eax, rdi
; ================
; rdi - first no-zero in string buffer
printNumber:
	enter 	0, 0
	push r9
	push r8
	push rsi
	push rdx
	xor 	r8, r8
	mov 	r9, rdi

	xor 	ax, ax
	mov 	ax, IntSize
	div 	cl
	cmp 	ah, 0 ; check if can be evenly splitted
	je evenPrint
	push 	rcx
	xor 	rcx, rcx
	mov 	cl, ah
	call 	getUpperMask
	mov 	eax, ebx
	and 	eax, edx
	rol		eax, cl
	add 	eax, '0'
	stosb
	cmp	 	eax, '0'
	je 		noOverflowInPrnt
	mov 	r8, rdi
	noOverflowInPrnt:
	shl 	ebx, cl
	pop 	rcx
	evenPrint:

	xor 	edx, edx
	mov 	eax, IntSize
	div 	ecx
	mov 	edx, eax

	charByChar:
		push rdx
		xor 	rax, rax
		mov 	eax, ebx
		shl 	ebx, cl
		call 	getUpperMask
		and 	eax, edx
		rol 	eax, cl

		cmp 	eax, 10
		jl  	setLetter
		add 	eax, 7
		setLetter:
		add		eax, '0'
		stosb
		pop rdx

		sub		eax, '0'
		cmp		r8, 0
		jne 	.startAlreadyFound
		cmp		eax, 0
		je 		.startAlreadyFound
		mov 	r8, rdi
		sub 	r8, 1
		.startAlreadyFound:
		dec 	edx
	cmp 	edx, 0
	jne 	charByChar

	mov 	eax, 0
	stosb
	mov 	rdi, r8

	test 	rdi, rdi
	jne 	.finish
	mov 	rdi, r9
	mov 	byte [rdi + 1], 0
	.finish:
	pop rdx
	pop rsi
	pop r8
	pop r9
	leave
	ret

; Mask of cx upper bits
; ================
; cl - power
; ================
; edx - mask
getUpperMask:
	mov 	edx, -1 ; all F
	shr 	edx, cl
	not 	edx
	ret


; Prints decimal number to desired string
; ================
; (c) eax - number
; (c) rdi - string buffer
; ================
; Contaminated: rcx, rdx, rax, rdi
; ================
printDecimalNumber:
	enter 0, 0
	push rax
	push rdx
	xor 	edx, edx
	mov 	ecx, 10
	div 	ecx
	test 	eax, eax
	je .l1
		call printDecimalNumber
	.l1:
	lea 	eax, [edx+'0']
	stosb
	mov 	byte [rdi], 0
	pop rdx
	pop rax
	leave
	ret

; Count char in str
; ================
; rsi - source string
; rbx - character
; ================
; rcx - counted chars
countChar:
	push 	rax
	xor 	rcx, rcx
	.loop:
		lodsb
		cmp 	al, 0
		je  	.loopEnd
		
		cmp 	al, bl
		jne 	.continue
		
		inc 	rcx
		.continue:
		jmp .loop
	.loopEnd:
	pop 	rax
	ret
