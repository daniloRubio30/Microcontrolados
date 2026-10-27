; Pisca o led D1 (PN1) a 1 Hz

; Adaptado do código de Jonathan Valvano (na versão do Guilherme Peron e
; Paulo da Luz), por Juliano M Vieira

        AREA reset,READONLY
        DCD stack_inic
        DCD inicio

        ; =============================
        ;  DEFINIÇÕES DE REGISTROS I/O
        ; =============================

SYSCTL_RCGCGPIO_R       EQU 0x400FE608
SYSCTL_PRGPIO_R         EQU 0x400FEA08
GPIO_PORTN_AHB_DIR_R    EQU 0x40064400
GPIO_PORTN_AHB_AFSEL_R  EQU 0x40064420
GPIO_PORTN_AHB_DEN_R    EQU 0x4006451C
GPIO_PORTN_AHB_AMSEL_R  EQU 0x40064528
GPIO_PORTN_AHB_DATA_R   EQU 0x400643FC
NVIC_ST_CTRL_R        	EQU 0xE000E010
NVIC_ST_RELOAD_R      	EQU 0xE000E014
NVIC_ST_CURRENT_R     	EQU 0xE000E018

        ; =============================
        ;      PROGRAMA PRINCIPAL
        ; =============================

        AREA principal,CODE,READONLY

inicio
        BL      inicia_GPIO
        BL      inicia_systick
        LDR     R1,=GPIO_PORTN_AHB_DATA_R

loop_infinito
        LDR     R2,[R1]
        ORR     R2,R2,#2_00000010
        STR     R2,[R1]             ; acende led D1 (em PN1)
        LDR     R0,=500             ; recarrega R0
        BL      wait_ms             ; espera 500 milissegundos
        
        LDR     R2,[R1]
        BIC     R2,R2,#2_00000010
        STR     R2,[R1]             ; apaga led D1 (em PN1)
        LDR     R0,=500             ; recarrega R0
        BL      wait_ms
        
        B       loop_infinito

        ; ========================
        ;  INICIALIZAÇÃO DA GPIO
        ; ========================
       
inicia_GPIO
        LDR     R0,=SYSCTL_RCGCGPIO_R
        LDR     R1,[R0]
        ; Portas (bits)QPNMLKJHGFEDCBA
        LDR     R2,=2_0001000000000000
        MVN     R3,R2
        AND     R4,R1,R3
        ORR     R1,R4,R2
        STR     R1,[R0]

        ; ----- Espera as portas ficarem prontas -----
        LDR     R0,=SYSCTL_PRGPIO_R
espera_ativar
        LDR     R2,[R0]
        AND     R2,R2,R1  ; isola os bits de interesse
        CMP     R2,R1
        BNE     espera_ativar

        ; ----- Configura direção E/S dos pinos -----
        LDR     R0,=GPIO_PORTN_AHB_DIR_R
        LDR     R1,[R0]
        ; seta bits de saídas PN1
        ORR     R1,R1,#2_00000010
        STR     R1,[R0]

        ; ----- Desabilita uso de periféricos internos -----
        LDR     R0,=GPIO_PORTN_AHB_AFSEL_R
        LDR     R1,[R0]
        ; zera bits dos 8 pinos
        LDR     R3,=2_11111111111111111111111100000000
        AND     R1,R1,R3        
        STR     R1,[R0]

        ; ----- Seleciona função digital -----
        LDR     R0,=GPIO_PORTN_AHB_DEN_R
        LDR     R1,[R0]
        ; seta bits de saídas PN1
        ORR     R1,R1,#2_00000010
        STR     R1,[R0]

        ; ----- Desabilita módulo analógico -----
        LDR     R0,=GPIO_PORTN_AHB_AMSEL_R
        LDR     R1,[R0]
        ; zera bits dos 8 pinos
        LDR     R3,=2_11111111111111111111111100000000
        AND     R1,R1,R3        
        STR     R1,[R0]

        ; Não estamos configurando as saídas do port N
        ; => Estão no seu default max 2mA (do reset)
                
        ; ----- Finaliza a função -----
        BX      LR

        ; ==========================
        ;  INICIALIZAÇÃO DO SYSTICK
        ; ==========================

		; Configura Timer do SysTick

inicia_systick
        PUSH    {R0,R1}
		; ----- Esta inicialização poderia ser mais prudente -----
        LDR     R1,=NVIC_ST_CTRL_R
        MOV 	R0, #0x05           ; habilita o timer com 
        STR 	R0, [R1]            ;   clock do sistema
        POP     {R0,R1}
        BX 		LR

        ; ============================
        ;   TEMPORIZAÇÃO PARA ESPERA
        ; ============================

        ; Espera o número de milissegundos
        ; especificado no registrador R0
        ; DESTRÓI R0!!!

wait_ms
        PUSH    {R1,R2}

        ; ----- espera 1 ms com systick -----
timer_1_ms
        LDR     R1,=NVIC_ST_RELOAD_R
        LDR     R2,=15999           ; 16000 clocks - 1
        STR 	R2, [R1]            ; @16MHz, dá 1 ms
        LDR 	R1,=NVIC_ST_CTRL_R
wait_loop
        LDR 	R2, [R1]
        TST     R2,#0x00010000       ; bit 16 indica final da contagem
        BEQ 	wait_loop

        ; ----- decrementa e repete espera de 1ms se R0>0 -----
        ADDS    R0,R0,#-1
        BNE     timer_1_ms

        ; -----  finaliza -----
        POP     {R1,R2}
        BX      LR


; -------------------------
;       AREA DA PILHA
; -------------------------
        AREA stack,DATA,READWRITE,ALIGN=3
        SPACE 200
stack_inic


        END
