; =========================================================
; CONSTANTES
; =========================================================

LISTA_ORIGINAL  EQU 0x20000400
LISTA_PRIMOS    EQU 0x20000500
TAM_LISTA       EQU 20
STACK_SIZE      EQU 0x00000400

        AREA reset, DATA, READONLY

        DCD __initial_sp
        DCD inicio

        AREA stack, NOINIT, READWRITE, ALIGN=3

stack_mem
        SPACE STACK_SIZE

__initial_sp



        AREA dados, DATA, READONLY

ListaInicial
        DCD 193, 63, 176, 127, 43
        DCD 13, 211, 3, 203, 5
        DCD 21, 7, 206, 245, 157
        DCD 237, 241, 105, 252, 19




        AREA codigo, CODE, READONLY
        ENTRY



inicio

        LDR R0, =LISTA_ORIGINAL    ; endereço destino
        LDR R1, =ListaInicial      ; endereço da lista definida com DCD
        MOV R2, #TAM_LISTA         ; 20 elementos

        PUSH {R0}                  ; guarda endereço inicial da lista


copia_lista

        LDR R3, [R1]               ; lê elemento da ListaInicial
        STR R3, [R0]               ; grava em 0x20000400

        ADD R0, R0, #4             ; próxima posição de destino
        ADD R1, R1, #4             ; próximo elemento da origem

        SUBS R2, R2, #1
        BNE copia_lista


        POP {R0}                   ; R0 volta a valer 0x20000400


; =========================================================
; 2 - BUBBLE SORT
;
; R7 = tam, conforme pedido no enunciado
;
; R0 = início da lista
; R1 = ponteiro que percorre a lista
; R2 = número de comparações da passada
; R3 = contador interno
; R4 = valor atual
; R5 = próximo valor
; =========================================================

        MOV R7, #TAM_LISTA         ; tam = 20

        MOV R1, R0                 ; ponteiro para lista
        MOV R2, R7
        SUB R2, R2, #1             ; primeira passada = 19 comparações


loop_externo

        MOV R1, R0                 ; volta para o início
        MOV R3, R2                 ; comparações desta passada


loop_interno

        LDR R4, [R1]               ; elemento atual
        LDR R5, [R1, #4]           ; próximo elemento

        CMP R4, R5

        BLS nao_troca              ; se atual <= próximo, não troca


        ; atual > próximo
        ; troca os dois valores

        STR R5, [R1]               ; menor fica antes
        STR R4, [R1, #4]           ; maior fica depois


nao_troca

        ADD R1, R1, #4             ; passa para o próximo par

        SUBS R3, R3, #1
        BNE loop_interno


        SUBS R2, R2, #1
        BNE loop_externo


; =========================================================
; 3 - FILTRAR NÚMEROS PRIMOS
;
; R1 = ponteiro para lista ordenada
; R2 = ponteiro para lista de primos
; R3 = quantidade de primos encontrados
; R6 = número sendo testado
; R7 = quantidade de números ainda a verificar
;
; O resultado do teste deve ficar em R5:
;
; R5 = 1 -> primo
; R5 = 0 -> não primo
; =========================================================

        LDR R1, =LISTA_ORIGINAL
        LDR R2, =LISTA_PRIMOS

        MOV R7, #TAM_LISTA
        MOV R3, #0                 ; nenhum primo encontrado ainda


verifica_lista

        LDR R6, [R1]               ; R6 = número atual


; =========================================================
; 4 - PRIMO
;
; R6 = número
; R5 = resultado
;
; R4 = possível divisor
; R8 = resultado da divisão
; R9 = resultado da multiplicação
; =========================================================

        CMP R6, #2
        BLO numero_nao_primo       ; 0 e 1 não são primos

        MOV R4, #2                 ; começa testando divisor 2


testa_divisor

        CMP R4, R6

        ; Se chegamos até o próprio número sem achar
        ; divisor anterior, então ele é primo.

        BEQ numero_primo


        ; -----------------------------------------
        ; Teste de múltiplo:
        ;
        ; R8 = R6 / R4
        ; R9 = R8 * R4
        ;
        ; Se R9 == R6, divisão foi exata.
        ; -----------------------------------------

        UDIV R8, R6, R4
        MUL  R9, R8, R4

        CMP R9, R6
        BEQ numero_nao_primo       ; encontrou divisor


        ADD R4, R4, #1             ; próximo possível divisor
        B testa_divisor


; =========================================================
; NÚMERO É PRIMO
; =========================================================

numero_primo

        MOV R5, #1                 ; resultado do teste = primo

        STR R6, [R2]               ; grava em 0x20000500
        ADD R2, R2, #4             ; próxima posição da lista de primos

        ADD R3, R3, #1             ; quantidade de primos++

        B proximo_numero



numero_nao_primo

        MOV R5, #0                 ; não primo



proximo_numero

        ADD R1, R1, #4             ; próximo elemento de 0x20000400

        SUBS R7, R7, #1
        BNE verifica_lista

        MOV R0, R3                 ; R0 = quantidade de primos encontrados


fim

        B fim


        END