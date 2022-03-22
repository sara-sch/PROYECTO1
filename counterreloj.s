; Estado 0: reloj
PROCESSOR 16F887

; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
  
; -------------- MACROS --------------- 
; Macro para reiniciar el valor del TMR0
RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
  
PSECT udata_shr			 ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    msegundos:		DS 1	; Contador TMR0
    segundos:		DS 1	; Contador segundos
    minutos1:		DS 1	; Contador unidades de minuto
    minutos2:		DS 1	; Contador decenas de minuto
    horas1:		DS 1	; Contador unidades de horas
    horas2:		DS 1	; Contador decenas de minuto
    banderas:		DS 1	; Banderas para mostrar valores en displays
    M1:			DS 1	; Unidades de minutos con valor de tabla de 7 seg
    M2:			DS 1	; Decenas de minutos con valor de tabla de 7 seg
    H1:			DS 1	; Unidades de horas con valor de tabla de 7 seg
    H2:			DS 1	; Decenas de horas con valor de tabla de 7 seg
    valor:		DS 1	; Contador para edición manual de reloj
    cantidad:		DS 1	; Contador 2 para edición manual de reloj
    ECHECK:		DS 1	; Registro de chequeo para estados (tmr0)
    
PSECT udata_bank0
    ECHECKL:		DS 1	; Registro de chequeo para estados (loop)
    ECHECKB:		DS 1	; Registro de chequeo para estados (botón)
     
PSECT resVect, class = CODE, abs, delta = 2
; -------------------- VECTOR RESET -----------------------
 
ORG 00h
resVect:
	PAGESEL main	    ; cambio de pagina
	GOTO main
	
PSECT intVect, class=CODE, abs, delta=2
;---------------------interrupt vector---------------------
ORG 04h
PUSH:
    MOVWF   W_TEMP	    ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	    ; Guardamos STATUS
    
ISR:  
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_IOCB		; Si -> Subrutina de interrupción de PORTB
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0		; Si -> Subrutina de interrupción de TMR0
    
POP:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

;---------------------subrutinas de int--------------------    

INT_IOCB:
    BANKSEL PORTA
    BTFSS   PORTA, 1
    GOTO    ESTADO_1
    
    ESTADO_0:
	BTFSC   PORTB, 0	; Primer botón (estado)
	GOTO	$+2
	BCF	PORTA, 1
	

	BTFSC   PORTB, 1	; Botón incremento
	GOTO    $+2
	INCF    valor	; Incremento de contador

	BTFSC   PORTB, 2	; Botón decremento
	GOTO    $+2
	DECF    valor	; Decremento de contador

	BTFSC   ECHECKB, 0
	GOTO    BE1

	BE0:
	    BTFSC   PORTB, 3	; Inicia conteo de reloj automático
	    GOTO    $+5
	    BSF	    ECHECK,  0	; Configuraciones para ir al estado correspondiente
	    BSF	    ECHECKL, 0
	    BSF	    ECHECKB, 0
	    BCF	    PORTA,   0	; LED de configuración
	    BCF	    RBIF
	    RETURN

	BE1:
	    BTFSC   PORTB, 3	; Para conteo de reloj automático
	    GOTO    $+6
	    BCF	    ECHECK,  0	; Configuraciones para ir al estado correspondiente
	    BCF	    ECHECKL, 0
	    BCF	    ECHECKB, 0
	    BSF	    PORTA,   0	; LED de configuración
	    CLRF	    valor
	    BCF	    RBIF
	    RETURN

    ESTADO_1:
    
    RETURN
    
    
INT_TMR0:
    BTFSC   ECHECK, 0		; Verificamos en que estado estamos 
    GOTO    E01
    
    E00:			; Estado de configuración manual de reloj
	RESET_TMR0 255		; Reset del TMR0	2ms
	CALL    MOSTRAR_VALOR	; Mostramos valor en los displays
	RETURN
	
    E01:			; Estado de funcionamiento automático de reloj
	RESET_TMR0 255		; Reset del TMR0	2ms
	CALL    COUNTER		; Contadores
	CALL    MOSTRAR_VALOR	; Mostramos valor en los displays
	RETURN

PSECT code, delta = 2, abs
 
; -------------------- CONFIGURATION ---------------------
ORG 100h
main:
    CALL CONFIG_IO	; Configuraciones para que el programa funcione correctamente
    CALL CONFIG_RELOJ
    CALL CONFIG_IOCB
    CALL CONFIG_INT
    CALL CONFIG_TMR0
    CLRF msegundos	; Asegurando que msegundos y valor empiecen en 0
    CLRF    valor
    BSF	    PORTA, 1
    BANKSEL PORTA
        
LOOP:					; Verificamos en que estado estamos 
    BTFSC   ECHECKL, 0
    GOTO    E03
    
    E02:				; Estado de configuración manual de reloj
	MOVF    valor, W		
	MOVWF   cantidad
	CALL    COUNTER_CONFIG
	CALL    SET_DISPLAY
	GOTO    LOOP
	
    E03:				; Estado de funcionamiento automático de reloj
	CALL    SET_DISPLAY
	GOTO    LOOP
    
; ----------------------subrutinas------------------------
	
CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH		; I/O digitales
    
    BANKSEL TRISA
    BCF	    TRISA, 0
    BCF	    TRISA, 1
    CLRF    TRISC		; PORTC como salida
    BCF	    TRISD, 0		; RD0 como salida / D0
    BCF	    TRISD, 1		; RD1 como salida / D1
    BCF	    TRISD, 2		; RD3 como salida / D2
    BCF	    TRISD, 3		; RD4 como salida / D3
    BSF	    PORTB, 0		; PORTB0 como entrada 
    BSF	    PORTB, 1		; PORTB1 como entrada 
    BSF	    PORTB, 2		; PORTB2 como entrada 
    BSF	    PORTB, 3		; PORTB2 como entrada 
    
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7	; PORTB Pull-up habilitado

    BANKSEL WPUB
    BSF	    WPUB, 0		; PORTB0 habilitado como Pull-up
    BSF	    WPUB, 1		; PORTB1 habilitado como Pull-up
    BSF	    WPUB, 2		; PORTB2 habilitado como Pull-up
    BSF	    WPUB, 3		; PORTB2 habilitado como Pull-up
    
    BANKSEL PORTA
    CLRF    PORTA		;Limpieza de puertos
    CLRF    PORTC
    CLRF    PORTD
    CLRF    PORTB
    
    RETURN
    
CONFIG_RELOJ:
    BANKSEL OSCCON	; Cambiamos a banco 1
    BSF OSCCON, 0	; scs -> 1, usamos reloj interno
    BCF OSCCON, 6
    BSF OSCCON, 5
    BSF OSCCON, 4	; IRCF<2:0> -> 011 500kHz
    RETURN
    
CONFIG_TMR0:
    BANKSEL OPTION_REG	; Cambiamos de banco
    BCF T0CS		; TMR0 como temporizador
    BCF PSA		; Prescaler a TMR0
    BSF PS2
    BSF PS1
    BSF PS0		; PS<2:0> -> 111 PRESCALER 1 : 256
    
    BANKSEL TMR0	; Cambiamos de banco
    MOVLW 255
    MOVWF TMR0		; 2ms retardo
    BCF T0IF		; Limpiamos bandera de interrupción
    RETURN
    
CONFIG_IOCB:
    BANKSEL TRISA
    BSF	    IOCB, 0		; Interrupción habilitada en PORTB0
    BSF	    IOCB, 1		; Interrupción habilitada en PORTB1
    BSF	    IOCB, 2		; Interrupción habilitada en PORTB2
    BSF	    IOCB, 3		; Interrupción habilitada en PORTB2

    BANKSEL PORTB
    MOVF    PORTB, W	        ; Al leer, deja de hacer mismatch
    BCF	    RBIF		; Limpiamos bandera de interrupción
    RETURN
 
    
CONFIG_INT:
    BANKSEL INTCON
    BSF	    PEIE	    ; Habilitamos int. perifericos
    BSF	    GIE		    ; Habilitamos interrupciones
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de TMR0
    BSF	    RBIE	    ; Habilitamos interrupcion RBIE
    BCF	    RBIF	    ; Limpia bandera RBIF
    RETURN
   
COUNTER_CONFIG: 
    BSF	    PORTA, 0
    CALL    TENSHRS
    CALL    UNITSHRS
    CALL    TENSMINS
    CALL    UNITSMINS
    RETURN 
    
TENSHRS:
    CLRF    horas2
    MOVLW   4		    ;10
    SUBWF   horas1, F		
    BTFSS   STATUS, 0		; Skip if carry
    GOTO    $+3
    INCF    horas2		; Incrementamos contador de centenas
    GOTO    $-5
    RETURN

UNITSHRS:
    CLRF    horas1
    MOVLW   60
    SUBWF   cantidad, F
    BTFSS   STATUS, 0		; Skip if carry
    GOTO    $+3
    INCF    horas1		; Incrementamos contador de decenas
    GOTO    $-5
    RETURN

TENSMINS:
    MOVLW   60	
    ADDWF   cantidad, F		; Sumar 100 al contador en decimales
    CLRF    minutos2
    MOVLW   10
    SUBWF   cantidad, F
    BTFSS   STATUS, 0		; Skip if carry
    GOTO    $+3
    INCF    minutos2		; Incrementamos contador de decenas
    GOTO    $-5
    RETURN
    
UNITSMINS:
    MOVLW   10
    ADDWF   cantidad, F		; Sumar 10 al contador en decimales
    CLRF    minutos1
    MOVF    cantidad, W
    MOVWF   minutos1		; Guardar valor en registro
    RETURN
    
    
    /*COUNTER_CONFIG: 
    CALL    TENSHRS
    CALL    UNITSHRS
    CALL    TENSMINS
    CALL    UNITSMINS
    MOVF    hh1, W
    ADDWF   horas1
    RETURN 
    
    
TENSHRS:
    CLRF    horas2
    MOVLW   10		    ;10
    SUBWF   horas1, F
    BTFSS   STATUS, 0
    GOTO    $+4
    INCF    horas2		; Guardar valor en registro
    CLRF    horas1
    GOTO    $-6
    RETURN

UNITSHRS:
    CLRF    horas1
    MOVLW   60
    SUBWF   cantidad, F
    BTFSS   STATUS, 0		; Skip if carry
    GOTO    $+5
    INCF    horas1		; Incrementamos contador de decenas
    MOVF    horas1, W
    ADDWF   hh1
    CLRF    valor
    RETURN

TENSMINS:
    MOVLW   60
    ADDWF   cantidad
    CLRF    minutos2
    MOVLW   10
    SUBWF   cantidad, F
    BTFSS   STATUS, 0		; Skip if carry
    GOTO    $+3
    INCF    minutos2		; Incrementamos contador de decenas
    GOTO    $-5
    RETURN
    
UNITSMINS:
    MOVLW   10
    ADDWF   cantidad, F		; Sumar 10 al contador en decimales
    CLRF    minutos1
    MOVF    cantidad, W
    MOVWF   minutos1		; Guardar valor en registro
    RETURN
    */
    
    /*
    
    MOVF    valor, W
    MOVWF   minutos1
    MOVLW   10		;10
    SUBWF   valor, W
    BTFSS   STATUS, 2
    GOTO    $+17
    INCF    minutos2
    CLRF    minutos1
    CLRF    valor
    MOVLW   6 ;6
    SUBWF   minutos2, W
    BTFSS   STATUS, 2
    GOTO    $+10
    INCF    horas1
    CLRF    minutos2
    CALL    CHECKTF
    MOVLW   10
    SUBWF   horas1, W
    BTFSS   STATUS, 2
    GOTO    $+3
    INCF    horas2
    CLRF    horas1
    RETURN
    
CHECKTF:
    MOVLW   2	;2
    SUBWF   horas2, W
    BTFSS   STATUS, 2
    RETURN
    MOVLW   4
    SUBWF   horas1, W
    BTFSS   STATUS, 2
    RETURN
    CLRF    minutos1		
    CLRF    minutos2		
    CLRF    horas1
    CLRF    horas2
    RETURN
    
     */
    ;-------------------------------------------------------------------
    
COUNTER:   
    INCF    msegundos
    MOVLW   100 ;500
    XORWF   msegundos, W
    BTFSS   STATUS, 2
    RETURN
    INCF    segundos
    MOVLW   2	;60
    XORWF   segundos, W
    BTFSC   STATUS, 2
    CALL    COUNTERM1
    BTFSC   STATUS, 2		; Si se activa la bandera Z -- Después de 10s
    CALL    COUNTERM2
    BTFSC   STATUS, 2		; Si se activa la bandera Z -- Después de 10s
    CALL    COUNTERM3
    BTFSC   STATUS, 2		; Si se activa la bandera Z -- Después de 10s
    CALL    COUNTERM4
    
    CLRF    STATUS		; Limpiamos bandera STATUS
    CLRF    msegundos
    RETURN
    
    COUNTERM1:
    RESET_TMR0 255		; Reinicio de TMR0
    CLRF    segundos		; Limpiamos contador interno de display 1
    
    INCF    minutos1		; Incremento del contador de display 2
    MOVLW   10		;10
    XORWF   minutos1, W
    RETURN  
    
    COUNTERM2:
    RESET_TMR0 255		; Reinicio de TMR0
    CLRF    minutos1		; Limpiamos contador interno de display 1
    
    INCF    minutos2		; Incremento del contador de display 2
    MOVLW   6			;6
    XORWF   minutos2, W
    RETURN  
    
    COUNTERM3:
    RESET_TMR0 255		; Reinicio de TMR0
    CLRF    minutos2		; Limpiamos contador interno de display 1
    
    MOVLW   2 ;2
    XORWF   horas2, W
    BTFSS   STATUS, 2 
    GOTO    $+5
    MOVLW   3 ;3
    XORWF   horas1, W
    BTFSC   STATUS, 2
    GOTO    RESETCNTS
    
    INCF    horas1		; Incremento del contador de display 2
    MOVLW   10		;10
    XORWF   horas1, W
    RETURN  
    
    COUNTERM4:
    RESET_TMR0 255		; Reinicio de TMR0
    CLRF    horas1		; Limpiamos contador interno de display 1
    
    INCF    horas2		; Incremento del contador de display 2
    RETURN
   
    
RESETCNTS:
    RESET_TMR0 255		; Reinicio de TMR0
    CLRF    msegundos		; Limpiamos contadores de ambos displays CONT
    CLRF    segundos		; CONT2
    CLRF    minutos1		; COUNT
    CLRF    minutos2		; COUNT2
    CLRF    horas1
    CLRF    horas2
    CLRF    STATUS		; Limpiamos bandera STATUS
    CLRF    msegundos
    GOTO    COUNTER
    
SET_DISPLAY:  
    MOVF    horas2, W		; 
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   H2		        ; Guardamos en decenas

    MOVF    horas1, W		;
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   H1			; Guardamos en centenas

    MOVF    minutos2, W		; 
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   M2			; Guardamos en decenas

    MOVF    minutos1, W		;
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   M1			; Guardamos en centenas
    RETURN
   
MOSTRAR_VALOR:
    BCF	    PORTD, 0		; Apagamos display de nibble alto
    BCF	    PORTD, 1		; Apagamos display de nibble bajo   
    BCF	    PORTD, 2		; Apagamos display 
    BCF	    PORTD, 3		; Apagamos display 
    
    BTFSC   banderas, 0		; Verificamos bandera
    GOTO    DISPLAY_0	
    BTFSC   banderas, 1		; Verificamos bandera
    GOTO    DISPLAY_1
    BTFSC   banderas, 2		; Verificamos bandera
    GOTO    DISPLAY_2
    BTFSC   banderas, 3		; Verificamos bandera
    GOTO    DISPLAY_3
    
    DISPLAY_0:			
	MOVF    H2, W		; Movemos display de decenas a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 0	; Encendemos display 
	BCF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BSF	banderas, 1	
    RETURN

    DISPLAY_1:
	MOVF    H1, W		; Movemos display de centenas a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 1	; Encendemos display 
	BCF	banderas, 1	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BSF	banderas, 2	
    RETURN
    
    DISPLAY_2:
	MOVF    M2, W		; Movemos display de unidades a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 2
	BCF	banderas, 2	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BSF	banderas, 3
    RETURN
    
    DISPLAY_3:
	MOVF    M1, W		; Movemos display de unidades a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 3
	CLRF	banderas
    RETURN
    

ORG 200h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    
END
    
