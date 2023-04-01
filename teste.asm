.MODEL  small

.STACK  1024

CR		EQU		0DH
LF		EQU		0AH

.DATA
    x               DQ      0   
    handle          DW      0 
    buffer          DB      0
    cl_string       DB      127 DUP(0)
    filename        DB      127 DUP(0)
    msgfilename     DB      "Nome de arquivo invalido e/ou parametros incorretos", CR, LF, 0
    MsgErroOpen		DB	    "Erro na abertura do arquivo.", CR, LF, 0
    MsgErroRead		DB	    "Erro na leitura do arquivo.", CR, LF, 0
    hexcode         DB      127 DUP(0)
    bool_g          DB      0
    bool_v          DB      0
        

.CODE
.STARTUP
    PUSH DS                                 ; salva as informações de segmentos
    PUSH ES
    MOV AX, DS                              ; troca DS <-> ES, para poder usa o MOVSB
    MOV BX, ES
    MOV DS, BX
    MOV ES, AX
    MOV SI, 80H                             ; obtém o tamanho do string e coloca em CX
    MOV CH, 0
    MOV CL, [SI]
    MOV SI, 82H                             ; inicializa o ponteiro de origem
    LEA DI, cl_string                             ; inicializa o ponteiro de destino
    REP MOVSB
    POP ES                                  ; retorna as informações dos registradores de segmentos
    POP DS

    ;-------- analisa cl_string ---------
    LEA     DI, cl_string
searching:
    CMP     BYTE PTR [DI], CR
    JE      exit                            ; Não encontrou '-'
    CMP     BYTE PTR [DI], '-'
    JE      found
    INC     DI
    JMP     searching  
found:
    MOV     DX, DI                 
    CALL    store_str                       ; store_str(DX -> endereço do caractere em questão: '-a', '-g' ou '-v')


    LEA     DI, filename
    CMP     BYTE PTR [DI], 0
    JE      exit

    ;-------- Abrindo Arquivo -----------
    MOV     AH, 3DH
    MOV     AL, 0
    LEA     DX, filename                  
    INT     21H                                 ; CF == 0, se ok 
    MOV     handle, AX                          ; handle = AX
    JNC     continue                        
    LEA     BX, MsgErroOpen
    CALL    printf_s
    JMP     exit

continue:
    ;-------- Leitura do Arquivo --------
    MOV     AH, 3FH
    MOV     BX, handle
    MOV     CX, 1H                              ; Número de bytes a serem lidos
    LEA     DX, buffer                          ; Buffer para receber bytes lidos
    INT     21H                                 ; CF == 0, se ok. AX == bytes-lidos -> AX == 0 se terminou o arquivo
    JNC     continue2                        
    LEA     BX, MsgErroRead
    CALL    printf_s
    JMP     exit      

continue2:
    CMP AX, 0
    JE  finaliza
    CALL sum_64bits
    JMP continue

finaliza:  

    ;-------- Imprime o código de verificação na tela -------------------
    mov AX, word ptr [x + 6] ; carrega os bytes mais significativos em DX
    TEST    AX, 0FFFFH
    JZ next_byte1
    call print_hex
next_byte1:    
    mov AX, word ptr [x + 4] ; carrega os bytes em posição 6 e 5 em CX
    TEST    AX, 0FFFFH
    JZ next_byte2
    call print_hex
next_byte2:
    mov AX, word ptr [x + 2] ; carrega os bytes em posição 4 e 3 em BX
    TEST AX, 0FFFFH
    JZ  next_byte3
    call print_hex
next_byte3:
    mov AX, word ptr [x]     ; carrega os bytes menos significativos em AX
    call print_hex



    ;-------- Fechando Arquivo ----------
    MOV     AH, 3EH
    MOV     BX, handle
    INT     21H                                 ; CF == 0, se ok

exit:
.EXIT


;----------------------------------------
;Função que armazena as informações da 
;		string da linha de comando
;----------------------------------------
store_str   PROC    NEAR
    MOV     SI, DX
    INC     SI

cmploop:
    CMP     BYTE PTR [SI], 'a'                        ; compara com a letra 'a' 
    JE      copy_filename
    CMP     BYTE PTR [SI], 'g'                         ; compara com a letra 'g'
    JE      show_hexcode
    CMP     BYTE PTR [SI], 'v'                       ; compara com a letra 'v'
    JE      compare_hexcode
    JMP     errorName                               ; parâmetro incorreto

copy_filename:
    LEA     DI, filename
    CMP     BYTE PTR [DI], 0                ; Verifica se o usuário colocou mais de dois "-a", ou seja, o filename já tem o nome de um arquivo
    JNE     errorName
    CMP     BYTE PTR [SI+1], ' '            ; Verifica se há espaço entre o "-a" e o nome do arquivo
    JNE     errorName
    ADD     SI, 2H

loop_copy:
    MOV     BL, BYTE PTR [SI]
    MOV     BYTE PTR [DI], BL
    INC     SI
    INC     DI
    CMP     BYTE PTR [SI], CR
    JE      fim 
    CMP     BYTE PTR [SI+1], '-'
    JNE     loop_copy
    ADD     SI, 2H
    JMP     cmploop

show_hexcode:
    MOV     bool_g, 1
    JMP     searching2

searching2:
    INC     SI
    CMP     BYTE PTR [SI], CR
    JE      fim                            ; Não encontrou '-'
    CMP     BYTE PTR [SI], '-'
    JNE     searching2
    INC     SI
    JMP     cmploop
    
compare_hexcode:
    MOV     bool_v, 1
    JMP     searching2

errorName:
    LEA     BX, msgfilename
    CALL    printf_s
fim:
    RET

store_str   ENDP

;----------------------------------------
;Função que soma um valor de 8 bits a uma
;		variável de 64 bits
;----------------------------------------
sum_64bits  PROC    NEAR
    mov AL, buffer         
    
    add BYTE PTR[x], AL
    adc BYTE PTR [x + 1], 0
    JNC end_sum
    add BYTE PTR [x + 2], 1
    adc BYTE PTR [x + 3], 0
    JNC end_sum
    add BYTE PTR [x + 4], 1
    adc BYTE PTR [x + 5], 0
    JNC end_sum
    add BYTE PTR [x + 5], 1
    adc BYTE PTR [x + 6], 0
    JNC end_sum
    add BYTE PTR [x + 7], 1
end_sum:
    RET
sum_64bits  ENDP

;----------------------------------------
;Função que imprime uma variável em HEX
;	AX -> número para imprimir
;----------------------------------------
print_hex PROC  NEAR   
    mov cx,4        ; print 4 hex digits (= 16 bits)
    print_digit:
        rol ax,1   ; move the currently left-most digit into the least significant 4 bits
        rol ax,1
        rol ax,1
        rol ax,1
        mov dl,al
        and dl,0FH  ; isolate the hex digit we want to print
        add dl,'0'  ; and convert it into a character..
        cmp dl,'9'  ; ...
        jbe ok     ; ...
        add dl,7    ; ... (for 'A'..'F')
    ok:            ; ...
        push ax    ; save EAX on the stack temporarily
        mov ah,2    ; INT 21H / AH=2: write character to stdout
        int 21H
        pop ax     ; restore EAX
        loop print_digit
        ret
print_hex ENDP


;----------------------------------------
;Função Escreve um string na tela
;		printf_s(char *s -> BX)
;----------------------------------------
printf_s	PROC	NEAR
	MOV		DL, [BX]
	CMP		DL, 0
	JE		ps_1

	PUSH	BX
	MOV		AH, 2
	INT		21H
	POP		BX

	INC		BX		
	JMP		printf_s
		
ps_1:
	RET
printf_s	ENDP

END