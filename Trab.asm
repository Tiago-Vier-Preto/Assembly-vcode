;========================================================================================
;                      ARQUITETURA E ORGANIZAÇÃO DE COMPUTADORES I - 2022/2
;                                         UFRGS
;                               NOME: TIAGO VIER PRETO
;                                  MATRÍCULA: 335523
;========================================================================================

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
    MsgFilename     DB      "Nome de arquivo invalido e/ou parametros incorretos", CR, LF, 0
    MsgErroOpen		DB	    "Erro na abertura do arquivo.", CR, LF, 0
    MsgErroRead		DB	    "Erro na leitura do arquivo.",  CR, LF, 0
    MsgErroName     DB      "Nenhum Filename informado", CR, LF, 0
    MsgVcode        DB      "O codigo de verificacao informado eh IGUAL ao do arquivo", CR, LF, 0
    MsgNoVcode      DB      "O codigo de verificacao informado eh DIFERENTE ao do arquivo", CR, LF, 0
    MsgCRLF			DB	    CR, LF, 0
    hexcode         DB      16 DUP('0'),0 
    stringHex       DB      16 DUP('0'),0
    bool_g          DB      0
    bool_v          DB      0
        

.CODE
.STARTUP
    PUSH DS                                 ; Salva as informações de segmentos
    PUSH ES
    MOV AX, DS                              ; Troca DS <-> ES, para poder usa o MOVSB
    MOV BX, ES
    MOV DS, BX
    MOV ES, AX
    MOV SI, 80H                             ; Obtém o tamanho do string e coloca em CX
    MOV CH, 0
    MOV CL, [SI]
    MOV SI, 82H                             ; Inicializa o ponteiro de origem
    LEA DI, cl_string                       ; Inicializa o ponteiro de destino
    REP MOVSB
    POP ES                                  ; Retorna as informações dos registradores de segmentos
    POP DS

    ;-------- analisa cl_string ---------
    LEA     DI, cl_string                   ; Inicializa ponteiro da string proveniente da command line
searching:
    CMP     BYTE PTR [DI], CR               ; Chegou ao final da string
    JE      exit                            ; Não encontrou '-'
    CMP     BYTE PTR [DI], '-'
    JE      found                           ; Encontrou a primeira aparição de '-'
    INC     DI
    JMP     searching  
found:
    MOV     DX, DI                 
    CALL    store_cl_string                 ; store_cl_string(DX -> endereço do caractere em questão: '-a', '-g' ou '-v')

flags:
    ;-------- confere se há flags --------
    TEST    bool_g, 0FFFFH                  ; Verifica se -g foi acionado
    JNZ     proximo
    TEST    bool_v, 0FFFFH                  ; Verifica se -v foi acionado
    JNZ     proximo
    JMP     exit

proximo:
    LEA     DI, filename
    CMP     BYTE PTR [DI], 0                ; Verifica se há filename
    JNZ     abrindo
    LEA     BX, MsgErroName                 ; Informa que o usuário não informou um filename
    CALL    printf_s
    JMP     exit

abrindo:
    ;-------- Abrindo Arquivo -----------
    MOV     AH, 3DH
    MOV     AL, 0
    LEA     DX, filename                  
    INT     21H                             ; CF == 0, se ok 
    MOV     handle, AX                      ; handle = AX
    JNC     continue                        
    LEA     BX, MsgErroOpen                 ; Informa ao usuário que houve um problema ao abrir o arquivo
    CALL    printf_s
    JMP     exit

continue:
    ;-------- Leitura do Arquivo --------
    MOV     AH, 3FH
    MOV     BX, handle
    MOV     CX, 1H                          ; Número de bytes a serem lidos
    LEA     DX, buffer                      ; Buffer para receber bytes lidos
    INT     21H                             ; CF == 0, se ok. AX == bytes-lidos -> AX == 0 se terminou o arquivo
    JNC     continue2                        
    LEA     BX, MsgErroRead                 ; Informa ao usuário que houve um problema ao ler o arquivo
    CALL    printf_s
    JMP     exit      
continue2:
    CMP AX, 0                               ; Verifica se chegou ao final do arquivo
    JE  finaliza
    LEA DI, x                               ; Ponteiro para variável de 64 bits
    MOV AL, buffer                          ; AL recebe o byte lido do arquivo
    CALL sum_64bits                         ; Soma byte a byte com a váriavel de 64 bits
    JMP continue

finaliza:  

    ;-------- Fechando Arquivo ----------
    MOV     AH, 3EH
    MOV     BX, handle
    INT     21H                             ; CF == 0, se ok

    ;--------  Testa flag -g  ----------- 
    TEST    bool_g, 0FFFFH                  ; Verifica se -g é True
    JE      next_flag

    ;-------- Imprime o código de verificação na tela -------------------
    LEA SI, x                               ; Ponteiro para variável de 64 bits
    LEA DI, stringHex                       ; Ponteiro para string que receberá o valor convertido
    CALL int64ToString                      ; Converte variável de 64 bits -> String hexASCII

inc_index:
    CMP BYTE PTR [DI], '0'                  ; Compara com '0' para não imprimir zeros à esquerda
    JNZ  show                               ; Pula se achou um caracter válido diferente de '0'
    INC  DI                                 ; Incremente DI
    JMP  inc_index

show:
    MOV BX, DI                              ; Imprime na tela a partir da posição da String onde não tem zeros à esquerda
    CALL printf_s

    LEA     BX, MsgCRLF                     ; CR e LF
    CALL    printf_s


next_flag:
    ;--------  Testa flag -v  ----------- 
    TEST    bool_v, 0FFH                    ; Verifica se -v é True
    JE      exit

    ;------- Verifica o código hex ------
convert_num:
    LEA  SI, x                              ; Ponteiro para x
    LEA  DI, stringHex                      ; Ponteiro para String
    CALL int64ToString                      ; Converte var de 64 bits em hexASCII e salva na stringHex

    MOV     AX, WORD PTR [hexcode + 14]     
    CMP     AX, WORD PTR [stringHex + 14]   ; Compara stringHex com hexcode (informada pelo usuário)
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode + 12]     
    CMP     AX, WORD PTR [stringHex + 12]   ; Compara word por word
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode + 10]
    CMP     AX, WORD PTR [stringHex + 10]   ; Caso os bytes/words não sejam iguais pula
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode + 8]
    CMP     AX, WORD PTR [stringHex + 8]    ; Compara todos os 16 bytes
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode + 6]
    CMP     AX, WORD PTR [stringHex + 6]    
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode + 4]
    CMP     AX, WORD PTR [stringHex + 4]    
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode + 4]
    CMP     AX, WORD PTR [stringHex + 4]    
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode + 2]
    CMP     AX, WORD PTR [stringHex + 2]    
    JNZ     false_code
    MOV     AX, WORD PTR [hexcode]
    CMP     AX, WORD PTR [stringHex]        
    JNZ     false_code

    LEA     BX, MsgVcode                    ; Imprime na tela que o código é igual
    CALL     printf_s
    JMP     crlf

false_code:
    LEA     BX, MsgNoVcode                  ; Imprime na tela que o código é diferente
    CALL    printf_s

crlf:
    LEA     BX, MsgCRLF                     ; CR e LF
    CALL    printf_s
    
exit:
.EXIT                                       ; Encerra o programa

;----------------------------------------
;Função que armazena as informações da 
;		string da linha de comando
;----------------------------------------
store_cl_string   PROC    NEAR
    MOV     SI, DX
    INC     SI                              ; Avança ponteiro da cl_string
    PUSH    AX

cmploop:
    CMP     BYTE PTR [SI], 'a'              ; compara com a letra 'a' 
    JE      copy_filename
    CMP     BYTE PTR [SI], 'g'              ; compara com a letra 'g'
    JE      show_hexcode
    CMP     BYTE PTR [SI], 'v'              ; compara com a letra 'v'
    JE      compare_hexcode
    JMP     errorName                       ; parâmetro incorreto

copy_filename:
    LEA     DI, filename
    CMP     BYTE PTR [DI], 0                ; Verifica se o usuário colocou mais de dois "-a", ou seja, o filename já tem o nome de um arquivo
    JNE     errorName
    CMP     BYTE PTR [SI+1], ' '            ; Verifica se há espaço entre o "-a" e o nome do arquivo
    JNE     errorName
plus_one:
    INC     SI
    CMP     BYTE PTR [SI], ' '              ; incrementa a posição até encontrar um caracter diferente de 'espaço'
    JE      plus_one
    CMP     BYTE PTR [SI], '-'              ; Caso encontre '-' = nenhum parâmetro foi passado e devolve erro 
    JE      errorName
    CMP     BYTE PTR [SI], CR               ; Caso encontre CR = nenhum parâmetro foi passado e devolve erro 
    JE      errorName

loop_copy:
    MOV     BL, BYTE PTR [SI]
    MOV     BYTE PTR [DI], BL               ; Copia byte a byte o filename informado pelo usuário e armazena numa variável
    INC     SI
    INC     DI                              ; Incrementa os ponteiros das strings        
    CMP     BYTE PTR [SI], CR
    JE      fim 
    CMP     BYTE PTR [SI+1], '-'            ; Caso encontre '-' a função para de copiar a string
    JNE     loop_copy
    ADD     SI, 2H
    JMP     cmploop                         ; Pula para o início para fazer outra verificação

loop_copy2:
    MOV     BL, BYTE PTR [SI]
    CMP     BL, 61H                         ; Verifica se a letra do número hexadecimal está em minúsculo
    JB      uppercase    
    SUB     BL, 20H                         ; Caso esteja em minúsculo transforma em maiúsculo 
uppercase:
    MOV     BYTE PTR [DI], BL               ; Copia o código hexadecimal fornecido para uma variável
    DEC     SI
    DEC     DI                              ; Decrementa os ponteiros
    CMP     BYTE PTR [SI], ' '
    JNZ     loop_copy2
    MOV     SI, AX                          ; Caso encontre um espaço, o código hexadecimal acabou e volta a procurar outras flags na cl_string
    JMP     searching2

show_hexcode:
    MOV     bool_g, 1                       ; -g = True
    JMP     searching2
searching2:                                 ; Procura por novas flags
    INC     SI
    CMP     BYTE PTR [SI], CR
    JE      fim                             ; Não encontrou '-' e finaliza a função
    CMP     BYTE PTR [SI], '-'
    JNE     searching2
    INC     SI
    JMP     cmploop                         ; Volta para o início
    
compare_hexcode:
    LEA     DI, hexcode
    ADD     DI, 15
    CMP     BYTE PTR [DI], '0'              ; Verifica se o usuário colocou mais de dois "-v", ou seja, o hexcode já tem um valor
    JNE     errorName
    CMP     BYTE PTR [SI+1], ' '            ; Verifica se há espaço entre o "-v" e o nome do arquivo
    JNE     errorName
plus_one2:
    INC     SI
    CMP     BYTE PTR [SI], ' '              ; incrementa a posição até encontrar um caracter diferente de 'espaço'
    JE      plus_one2
    CMP     BYTE PTR [SI], '-'              ; Caso encontre '-' = nenhum parâmetro foi passado e devolve erro 
    JE      errorName
    CMP     BYTE PTR [SI], CR               ; Caso encontre CR = nenhum parâmetro foi passado e devolve erro 
    JE      errorName
    MOV     bool_v, 1                       ; -v = True
end_code:
    INC     SI                              ; Incrementa o ponteiro da string até chegar à última posição do código hexadecimal
    CMP     BYTE PTR [SI], CR
    JZ      cr_code
    CMP     BYTE PTR [SI], ' '
    JNZ     end_code
    MOV     AX, SI                          ; Salva a posição do final do código hexadecimal para continuar depois
    DEC     SI
    JMP     loop_copy2                      ; Pula para copiar o código
cr_code:
    DEC SI
    MOV     AX, SI
    JMP     loop_copy2
errorName:
    LEA     BX, MsgFilename                 ; Imprime uma mensagem de erro
    CALL    printf_s
fim:
    POP     AX
    RET                                     ; Finaliza subrotina

store_cl_string   ENDP

;----------------------------------------
;Função que soma um valor de 8 bits a uma
;		variável de 64 bits
;AL -> byte para somar  DI -> var 64 bits
;----------------------------------------
sum_64bits  PROC    NEAR         
    ADD     BYTE PTR[DI], AL                ; Adiciona o valor ao byte menos significativo
    ADC     BYTE PTR [DI + 1], 0
    JNC     end_sum
    ADD     BYTE PTR [DI + 2], 1
    ADC     BYTE PTR [DI + 3], 0            ; Vai somando carry ao resto dos bytes
    JNC     end_sum
    ADD     BYTE PTR [DI + 4], 1
    ADC     BYTE PTR [DI + 5], 0
    JNC     end_sum                         ; Caso não gere carry, finaliza a subrotina
    ADD     BYTE PTR [DI + 5], 1
    ADC     BYTE PTR [DI + 6], 0
    JNC     end_sum
    ADD     BYTE PTR [DI + 7], 1
end_sum:
    RET
sum_64bits  ENDP

;----------------------------------------
;Função converte 1 byte em ASCII
;	AH -> número a converter
;	BX -> número convertido
;----------------------------------------
binToASCIIHex PROC  NEAR   
    mov cx,2                                 ; Realiza o procedimento 2 vezes 
    mov bx, 0 
convert_digit:
    ROL     AX, 1                            ; Move os 4 bits mais a esquerda para os 4 bits menos significativos
    ROL     AX, 1
    ROL     AX, 1
    ROL     AX, 1
    MOV     DL, al
    AND     DL, 0FH                          ; Isola o dígito hexadecimal 
    ADD     DL, '0'                          ; Converte para caracter
    CMP     DL, '9'                          ; Verifica se é maior que '9'
    JBE     ok2    
    ADD     DL, 7                            ; Soma se for entre 'A'...'F'
ok2:    
    MOV     BL, DL                           ; Armazena em BX o resultado 
    ROL     BX, 1                            ; Rotaciona o valor em BX para ele receber mais dados
    ROL     BX, 1
    ROL     BX, 1
    ROL     BX, 1
    ROL     BX, 1
    ROL     BX, 1
    ROL     BX, 1
    ROL     BX, 1
prox:  
    loop convert_digit                       ; Finaliza se CX==0
        RET                             
binToASCIIHex ENDP

;----------------------------------------
;Função converte uma variável de 64 bits
;	e armazena em uma string
;   DI -> endereço da string
;   SI -> endereço da var de 64 bits
;----------------------------------------
int64ToString PROC  NEAR  
    PUSH    AX
    PUSH    BX
    MOV     AX, 0

    MOV     AH, byte ptr [SI]                ; Converte byte a byte a variável de 64 bits
    CALL    binToASCIIHex
    MOV     WORD PTR [DI + 14], BX           ; Armazena o valor na string com o endereço comçando em DI

    MOV     AH, byte ptr [SI + 1]            
    CALL    binToASCIIHex
    MOV     WORD PTR [DI + 12], BX           ; Armazena o valor convertido na string 

    MOV     AH, byte ptr [SI + 2]
    CALL    binToASCIIHex                    ; utiliza a função binToASCIIHex para converter o byte
    MOV     WORD PTR [DI + 10], BX           

    MOV     AH, byte ptr [SI + 3]
    CALL    binToASCIIHex
    MOV     WORD PTR [DI + 8], BX            ; Insere de "trás para frente" na String, sendo que a String deve possuir 16 bytes    

    MOV     AH, byte ptr [SI + 4]
    CALL    binToASCIIHex
    MOV     WORD PTR [DI + 6], BX           

    MOV     AH, byte ptr [SI + 5]
    CALL    binToASCIIHex
    MOV     WORD PTR [DI + 4], BX            

    MOV     AH, byte ptr [SI + 6]
    CALL    binToASCIIHex
    MOV     WORD PTR [DI + 2], BX            

    MOV     AH, byte ptr [SI + 7]
    CALL    binToASCIIHex
    MOV     WORD PTR [DI], BX                

    POP BX
    POP AX
    RET                                     ; Finaliza a subrotina
int64ToString ENDP

;----------------------------------------
;Função Escreve um string na tela
;		printf_s(char *s -> BX)
;----------------------------------------
printf_s	PROC	NEAR
	MOV		DL, [BX]
	CMP		DL, 0
	JE		ps_1

	PUSH	BX
	MOV		AH, 2                           ; Imprime byte a byte até encontrar um 0 
	INT		21H
	POP		BX

	INC		BX		
	JMP		printf_s
		
ps_1:
	RET
printf_s	ENDP

END