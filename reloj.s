; Reloj completo
PROCESSOR 16F887

; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
  
; -------------- MACROS --------------- 
    
COMPARADOR  MACRO VAR1, CONST		    ; Macro que compara cierta variable con cierta constante
    MOVLW CONST
    SUBWF VAR1, 0
    BTFSS STATUS, 0
    RETURN
    ENDM
    
VALORES_DISP MACRO VAR1, VAR2, VAR3, VAR4   ; Macro que traslada variables a tabla de 7 seg
    MOVF VAR1, 0
    MOVWF DIS1
    MOVF VAR2, 0
    MOVWF DIS2
    MOVF VAR3, 0
    MOVWF DIS3
    MOVF VAR4, 0
    MOVWF DIS4
    ENDM
  
    
PSECT udata_shr			 ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    MIN_U:		DS 1	; Unidades de minutos
    HORA_U:		DS 1	; Unidades de horas
    DIA_U:		DS 1	; Unidades de dias
    MES_U:		DS 1	; Unidades de meses
    MIN_D:		DS 1	; Decenas de minutos
    HORA_D:		DS 1	; Decenas de horas
    DIA_D:		DS 1	; Decenas de dias
    MES_D:		DS 1	; Decenas de mesas
    FLAGE0:		DS 1	; Bandera estado 0
    FLAGE1:		DS 1	; Bandera estado 1
    FLAGE2:		DS 1	; Bandera estado 2
    ALARMA:		DS 1	; Bandera para alarma de timer
    
    
PSECT udata_bank0
    dias:		DS 2
    meses:		DS 2
    horas:		DS 2
    mins:		DS 2
    tmins:		DS 2	; Minutos de timer
    tsecs:		DS 2	; Segundos de timer
    DIS1:		DS 1	; Variables que almacenan datos que ingresaran a tabla de 7 seg
    DIS2:		DS 1
    DIS3:		DS 1
    DIS4:		DS 1
    LUCES:		DS 1	; Variable para luces intermitentes
    SEGS:		DS 1	; Variable para segundos
    banderas:		DS 1	; Banderas de displays
    TMIN_D:		DS 1	; Decenas de minutos de timer
    TMIN_U:		DS 1	; Unidades de minutos de timer
    TSEC_D:		DS 1	; Decenas de segundos de timer
    TSEC_U:		DS 1	; Unidades de segundos de timer
     
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
    BTFSC   T0IF		; Interrupción del TMR0
    CALL    INT_TMR0
    BTFSC   TMR1IF		; Interrupción del TMR1
    CALL    INT_TMR1
    BTFSC   TMR2IF		; Interrupción del TMR2
    CALL    INT_TMR2
    BTFSC   RBIF		; Interrupción del PORTB
    CALL    INT_IOCB
    
POP:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

;---------------------subrutinas de int--------------------   
INT_TMR0: ;2ms
    BANKSEL TMR0
    MOVLW 131
    MOVWF TMR0
    BCF T0IF
    CALL CUAL_DISP		; Displays
    RETURN
    
INT_TMR1: ;1s
    BANKSEL TMR1H
    MOVLW 00001011B
    MOVWF TMR1H 
    MOVLW 11011100B
    MOVWF TMR1L
    BCF TMR1IF
    INCF SEGS			; Segundos para reloj
    
    BTFSC  FLAGE2, 0		; Activa timer
    CALL TIMER
    
    RETURN
    
INT_TMR2: ;0.5s
    BCF TMR2IF
    INCF LUCES
    CALL INTERMITENTES		; Parpadeo de luces
    CLRF TMR2
    RETURN
    
INT_IOCB:
    BANKSEL PORTA		; DETERMINA ESTADO
    BTFSC   PORTA, 1 
    GOTO    ESTADO_0
    BTFSC   PORTA, 2
    GOTO    ESTADO_1
    BTFSC   PORTA, 3
    GOTO    ESTADO_2
    
    ESTADO_0:	; ESTADO RELOJ
	BTFSC   PORTB, 7	; BOTON CAMBIO DE ESTADO
	GOTO	$+5
	BCF	PORTA, 1
	BSF	PORTA, 2
	BCF	RBIF
	RETURN
	
	BTFSS PORTB, 3		; BOTON PARA INICIAR/PARAR RELOJ
	BSF	FLAGE0, 1
	
	BANKSEL FLAGE0		; BANDERAS DE DETERMINACIÓN DE SUBESTADO
	BTFSC	FLAGE0, 1
	GOTO	RELOJA
	BTFSC	FLAGE0, 3
	GOTO	EDIT_MINS
	GOTO	EDIT_HORAS
	
	RELOJA:	    ; SUBESTADO DE RELOJ AUTOMÁTICO
	    BTFSC FLAGE0, 2	;BANDERA PARA INICIAR/PARAR RELOJ
	    GOTO  STOP

	    START:
	    BSF	  FLAGE0, 0
	    BSF	  FLAGE0, 2
	    BCF	  PORTD, 0
	    BCF	  RBIF
	    RETURN

	    STOP:
	    BTFSS PORTB, 3
	    CLRF  FLAGE0
	    BCF	  RBIF
	    RETURN
	
	EDIT_HORAS: ; SUBESTADO DE EDICIÓN DE HORAS
	    BSF	    PORTD, 0
	    BTFSS PORTB, 4
	    BSF FLAGE0, 3
	    BTFSS PORTB, 6
	    INCF horas
	    BTFSS PORTB, 5
	    DECF horas

	    MOVF horas, W       
	    XORLW 24           ; CHEQUÉA SI SE LLEGÓ A 24 HRS
	    BTFSC STATUS, 2
	    CLRF horas
	    MOVF horas, W
	    XORLW 255		; CHEQUÉA SI HAY 0 HRS
	    BTFSS STATUS, 2
	    GOTO  $+3
	    MOVLW 23
	    MOVWF horas
	    CALL HORAS_A_DISP
	    BCF RBIF
	    RETURN

	
	EDIT_MINS:  ; SUBESTADO DE EDICIÓN DE MINUTOS
	    BSF	  PORTD, 0
	    BTFSS PORTB, 4
	    BCF	  FLAGE0, 3 
	    BTFSS PORTB, 6
	    INCF  mins
	    BTFSS PORTB, 5
	    DECF  mins

	    MOVF mins, W       
	    XORLW 60           ; CHEQUÉA SI SE LLEGÓ A 60
	    BTFSC STATUS, 2
	    CLRF mins
	    MOVF mins, W
	    XORLW 255      	; CHEQUÉA SI HAY 0 MINS
	    BTFSS STATUS, 2
	    GOTO $+3
	    MOVLW 59
	    MOVWF mins
	    CALL MINUTOS_A_DISP
	    BCF RBIF
	    RETURN
	
    ESTADO_1:	; ESTADO FECHA
	CLRF	FLAGE0
	BTFSC   PORTB, 7	; BOTON CAMBIO DE ESTADO
	GOTO	$+5
	BCF	PORTA, 2
	BSF	PORTA, 3
	BCF	RBIF
	RETURN
	
	BANKSEL FLAGE1		; BANDERAS DE DETERMINACIÓN DE SUBESTADO
	BTFSC	FLAGE1, 1
	GOTO	EDIT_DAYS
	GOTO	EDIT_MONTHS
	
	EDIT_DAYS:	    ; SUBESTADO DE EDICIÓN DE DÍAS
	    BTFSS PORTB, 4
	    BCF FLAGE1, 1
	    BTFSS PORTB, 6
	    INCF dias
	    BTFSS PORTB, 5
	    DECF dias
	    CALL QUE_MES
	    BCF RBIF
	    CALL DIAS_A_DISP
	    RETURN

	EDIT_MONTHS:	    ; SUBESTADO DE EDICIÓN DE MESES
	    BTFSS PORTB, 4
	    BSF	FLAGE1, 1
	    BTFSS PORTB, 6
	    INCF meses
	    BTFSS PORTB, 1
	    DECF meses
	    CALL QUE_MES
	    BCF RBIF
	    CALL MESES_A_DISP
	    RETURN
	    
    ESTADO_2:	; ESTADO TIMER
	    CLRF FLAGE1
	    BTFSC   PORTB, 7	; BOTÓN CAMBIO DE ESTADO
	    GOTO $+5
	    BCF	PORTA, 3
	    BSF	PORTA, 1
	    BCF	RBIF
	    RETURN
	    
	    BTFSS PORTB, 3	; BOTÓN PARA INICIAR TIMER
	    BSF	FLAGE2, 1

	    BANKSEL FLAGE2	; BANDERAS DE DETERMINACIÓN DE SUBESTADO
	    BTFSC   ALARMA, 0
	    GOTO    ALARM
	    BTFSC FLAGE2, 1
	    GOTO STARTT
	    BTFSC FLAGE2, 3
	    GOTO EDIT_SECS
	    GOTO EDIT_TMINS
	
	ALARM:			; SUBESTADO DE ALARMA
	    BSF ALARMA, 1
	    BTFSC PORTB, 4
	    GOTO $-2
	    BCF	PORTD, 1
	    CLRF ALARMA
	    RETURN
	    
	STARTT:			; SUBESTADO DE INICIO DE TIMER
	    BSF	  FLAGE2, 0
	    BCF	  PORTD, 0
	    BCF	  RBIF
	    RETURN

	
	EDIT_TMINS:		; SUBESTADO DE EDICIÓN DE MINUTOS DE TIMER	
	    BSF	    PORTD, 0
	    BTFSS PORTB, 4
	    BSF FLAGE2, 3
	    BTFSS PORTB, 6
	    INCF tmins
	    BTFSS PORTB, 5
	    DECF tmins

	    MOVF tmins, W       
	    XORLW 100           ; CHEQUÉA SI SE LLEGÓ A 100 MINS
	    BTFSC STATUS, 2
	    CLRF tmins
	    MOVF tmins, W
	    XORLW 255		; CHEQUÉA SI HAY 0 MINS
	    BTFSS STATUS, 2
	    GOTO $+3
	    MOVLW 99
	    MOVWF tmins
	    CALL TMINS_A_DISP
	    BCF RBIF
	    RETURN 

	
	EDIT_SECS:		; SUBESTADO DE EDICIÓN DE SEGUNDOS DE TIMER
	    BSF	  PORTD, 0
	    BTFSS PORTB, 4
	    BCF	  FLAGE2, 3 
	    BTFSS PORTB, 6
	    INCF  tsecs
	    BTFSS PORTB, 5
	    DECF  tsecs

	    MOVF tsecs, W       
	    XORLW 60            ; CHEQUÉA SI SE LLEGÓ A 60 SEGUNDOS
	    BTFSC STATUS, 2
	    CLRF tsecs
	    MOVF tsecs, W
	    XORLW 255		; CHEQUÉA SI HAY 0 SEGUNDOS
	    BTFSS STATUS, 2
	    GOTO  $+3
	    MOVLW 59
	    MOVWF tsecs
	    CALL TSECS_A_DISP
	    BCF RBIF
	    RETURN
	    
PSECT code, delta = 2, abs
 
; -------------------- MAIN PROG ---------------------
ORG 100h
main:
    CALL CONFIG_IO		; Configuraciones para que el programa funcione correctamente
    CALL CONFIG_RELOJ
    CALL CONFIG_INT
    CALL CONFIG_TMR0
    CALL CONFIG_TMR1
    CALL CONFIG_TMR2
    CALL LIMPIAR
    BSF	 PORTA, 1		; LED QUE INDICA INICIO EN ESTADO RELOJ
    INCF MES_U			; SE INCREMENTA DIA Y MES PARA EMPEZAR EN ENERO 1
    INCF DIA_U
    
LOOP:				; DETERMINA ESTADO
    BTFSC   PORTA, 1	    
    GOTO    ESTADO0
    BTFSC   PORTA, 2
    GOTO    ESTADO1
    BTFSC   PORTA, 3
    GOTO    ESTADO2
    
    ESTADO0:	    ; ESTADO RELOJ
	BTFSC   FLAGE0, 0
	GOTO    AUTO
    
    AJUSTE:
	VALORES_DISP HORA_D, HORA_U, MIN_D, MIN_U	; LOOP CONFIG DE RELOJ
	GOTO    LOOP
    
    AUTO:
	CALL    RELOJ					; LOOP RELOJ AUTOMÁTICO
	VALORES_DISP HORA_D, HORA_U, MIN_D, MIN_U
	GOTO    LOOP

    ESTADO1:	    ; ESTADO FECHA
	VALORES_DISP MES_D, MES_U, DIA_D, DIA_U
	GOTO    LOOP
	
    ESTADO2:	    ; ESTADO TIMER
	BTFSC ALARMA, 1
	GOTO  AL
    
	VALORES_DISP TMIN_D, TMIN_U, TSEC_D, TSEC_U	; LOOP TIMER AUTO/CONFIG
	GOTO    LOOP
    
	AL:						; LOOP ALARMA TIMER
	CALL ASTOPT
	GOTO LOOP
    
;-------------------------------subrutinas del programa----------------------------
  
TIMER:			; SUBRUTINA TIMER AUTOMÁTICO
    DECF tsecs
    MOVF tsecs, W
    XORLW 255
    BTFSS STATUS, 2	; UF SEGUNDOS
    GOTO $+4
    MOVLW 59
    MOVWF tsecs
    DECF tmins
    
    MOVF tmins, W
    XORLW 0
    BTFSS STATUS, 2
    GOTO $+5
    MOVF tsecs, W
    XORLW 0
    BTFSC STATUS, 2	
    CALL RESET_TIMER	
    
    MOVF tmins, W
    XORLW 255
    BTFSS STATUS, 2	; UF MINS
    GOTO $+6
    CLRF tsecs
    CLRF tmins
    BSF ALARMA, 0	; ACTIVAR ALARMA TIMER
    BSF	PORTD, 1
    CLRF FLAGE2 
    
    CALL TSECS_A_DISP
    CALL TMINS_A_DISP
    RETURN

RESET_TIMER:
    BSF ALARMA, 0	; ACTIVAR ALARMA TIMER
    BSF	PORTD, 1
    CLRF FLAGE2 
    RETURN
    
ASTOPT:			; APAGA ALARMA DESPUÉS DE 1 MIN
    COMPARADOR SEGS, 60 
    BCF	PORTD, 1
    CLRF ALARMA
    RETURN
    
 QUE_MES:		; SUBRUTINA QUE DETERMINA EL MES Y SU CANTIDAD RESPECTIVA DE DÍAS
    BANKSEL meses
    MOVF meses, W
    XORLW 1		;ENERO
    BTFSC STATUS, 2
    CALL MES31
    
    MOVF meses, W
    XORLW 2		;FEBRERO
    BTFSC STATUS, 2
    CALL MES28
    
    MOVF meses, W
    XORLW 3		;MARZO
    BTFSC STATUS, 2
    CALL MES31
    
    MOVF meses, W
    XORLW 4		;ABRIL
    BTFSC STATUS, 2
    CALL MES30
    
    MOVF meses, W
    XORLW 5		;MAYO
    BTFSC STATUS, 2
    CALL MES31
    
    MOVF meses, W
    XORLW 6		;JUNIO
    BTFSC STATUS, 2
    CALL MES30
    
    MOVF meses, W
    XORLW 7		;JULIO
    BTFSC STATUS, 2
    CALL MES31
    
    MOVF meses, W
    XORLW 8		;AGOSTO
    BTFSC STATUS, 2
    CALL MES31
    
    MOVF meses, W
    XORLW 9		;SEPTIEMBRE
    BTFSC STATUS, 2
    CALL MES30
    
    MOVF meses, W
    XORLW 10		;OCTUBRE
    BTFSC STATUS, 2
    CALL MES31
    
    MOVF meses, W
    XORLW 11		;NOVIEMBRE
    BTFSC STATUS, 2
    CALL MES30
    
    MOVF meses, W
    XORLW 12		;DICIEMBRE
    BTFSC STATUS, 2
    CALL MES31
    
    MOVF meses, W	; OF MESES
    XORLW 13
    BTFSS STATUS, 2
    GOTO  $+4
    MOVLW 1
    MOVWF meses
    CALL MESES_A_DISP
    
    MOVF meses, W
    XORLW 0		; UF MESES
    BTFSS STATUS, 2
    GOTO  $+4
    MOVLW 12
    MOVWF meses
    CALL MESES_A_DISP
    RETURN
    
 MES31:		    ; MES CON 31 DIAS
    MOVLW 32
    SUBWF dias, W 
    BTFSC STATUS, 0
    CALL RESET_MES
    MOVF dias, W
    XORLW 0
    BTFSC STATUS, 2
    CALL UF_MES31
    RETURN
    
MES30:		    ; MES CON 30 DIAS
    MOVLW 31
    SUBWF dias, W 
    BTFSC STATUS, 0
    CALL RESET_MES
    MOVF dias, W
    XORLW 0
    BTFSC STATUS, 2
    CALL UF_MES30
    RETURN
    
MES28:		    ; MES CON 28 DIAS
    MOVLW 29
    SUBWF dias, W 
    BTFSC STATUS, 0
    CALL RESET_MES
    MOVF dias, W
    XORLW 0
    BTFSC STATUS, 2
    CALL UF_MES28
    RETURN
	
 RELOJ:		    ; RELOJ AUTOMÁTICO HORAS Y MINUTOS
    COMPARADOR SEGS, 60 
    CLRF SEGS
    INCF MIN_U
    INCF EXTRA
    COMPARADOR MIN_U, 10 
    CLRF MIN_U
    INCF MIN_D
    COMPARADOR MIN_D, 6	  
    CLRF MIN_D
    INCF HORA_U
    COMPARADOR HORA_U, 10
    CLRF HORA_U
    INCF HORA_D
    RETURN 
    
CUAL_DISP:  ;LE METE LOS DIFERENTES VALORES A LOS DISPLAYS
    BCF	    PORTA, 4		; Apagamos display 
    BCF	    PORTA, 5		; Apagamos display    
    BCF	    PORTA, 6		; Apagamos display 
    BCF	    PORTA, 7		; Apagamos display 
    
    
    BTFSC   banderas, 0		; Verificamos bandera
    GOTO    DISPLAY1	
    BTFSC   banderas, 1		; Verificamos bandera
    GOTO    DISPLAY2
    BTFSC   banderas, 2		; Verificamos bandera
    GOTO    DISPLAY3
    BTFSC   banderas, 3		; Verificamos bandera
    GOTO    DISPLAY4
    
   DISPLAY1:
    CLRF PORTC
    BSF PORTA, 7
    BCF PORTA, 6
    BCF PORTA, 4
    BCF PORTA, 5
    MOVF DIS3, 0
    CALL TABLA_DIS
    MOVWF PORTC
    BCF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupci?n
    BSF	banderas, 1	
    RETURN
    
   DISPLAY2:
    CLRF PORTC
    BSF PORTA, 6
    BCF PORTA, 7
    BCF PORTA, 4
    BCF PORTA, 5
    MOVF DIS4, 0
    CALL TABLA_DIS
    MOVWF PORTC
    BCF	banderas, 1	; Cambiamos bandera para cambiar el otro display en la siguiente interrupci?n
    BSF	banderas, 2	
    RETURN
   
   DISPLAY3:
    CLRF PORTC
    BSF PORTA, 4 
    BCF PORTA, 7
    BCF PORTA, 5
    BCF PORTA, 6
    MOVF DIS1, 0
    CALL TABLA_DIS
    MOVWF PORTC
    BCF	banderas, 2	; Cambiamos bandera para cambiar el otro display en la siguiente interrupci?n
    BSF	banderas, 3
    RETURN
   
   DISPLAY4:
    CLRF PORTC
    BSF PORTA, 5 
    BCF PORTA, 7
    BCF PORTA, 4
    BCF PORTA, 6
    MOVF DIS2, 0
    CALL TABLA_DIS
    MOVWF PORTC
    BCF	banderas, 3	; Cambiamos bandera para cambiar el otro display en la siguiente interrupci?n
    BSF	banderas, 0
    RETURN
    
    INTERMITENTES: ;SUBRUTINA QUE ENCIENDE Y APAGA LAS LUCES INTERMITENTES
    BTFSC LUCES, 1
    GOTO APAGAR
    BSF PORTB, 2
    RETURN
   APAGAR:
    BCF PORTB, 2
    RETURN
;----------------------------SUBRUTINAS SECUNDARIAS------------------------------
    
MINUTOS_A_DISP:	    ; SEPARA REGISTER MINS EN UNIDADES Y DECENAS
    MOVF mins, W       
    MOVWF mins+1
    CLRF MIN_U
    CLRF MIN_D
    CALL DM	    ; OBTENEMOS DECENAS
    MOVLW 10                
    ADDWF mins+1, F
    CALL UM	    ; OBTENEMOS UNIDADES
    RETURN

HORAS_A_DISP:	    ; SEPARA REGISTER HORAS EN UNIDADES Y DECENAS
    MOVF horas, W
    MOVWF horas+1
    CLRF HORA_U
    CLRF HORA_D
    CALL DH	    ; OBTENEMOS DECENAS
    MOVLW 10
    ADDWF horas+1, F
    CALL UH	    ; OBTENEMOS UNIDADES
    RETURN
    
DIAS_A_DISP:	    ; SEPARA REGISTER DIAS EN UNIDADES Y DECENAS
    MOVF dias, W
    MOVWF dias+1
    CLRF DIA_U
    CLRF DIA_D
    CALL DD	    ; OBTENEMOS DECENAS
    MOVLW 10
    ADDWF dias+1, F
    CALL UD	    ; OBTENEMOS UNIDADES
    RETURN

MESES_A_DISP:	    ; SEPARA REGISTER MESES EN UNIDADES Y DECENAS
    MOVF meses, W
    MOVWF meses+1
    CLRF MES_U
    CLRF MES_D
    CALL DME	    ; OBTENEMOS DECENAS
    MOVLW 10
    ADDWF meses+1, F
    CALL UME	    ; OBTENEMOS UNIDADES
    MOVF meses, W
    RETURN
    
TMINS_A_DISP:	    ; SEPARA REGISTER MINUTOS DE TIMER EN UNIDADES Y DECENAS
    MOVF tmins, W
    MOVWF tmins+1
    CLRF TMIN_U
    CLRF TMIN_D
    CALL DTM	    ; OBTENEMOS DECENAS
    MOVLW 10
    ADDWF tmins+1, F
    CALL UTM	    ; OBTENEMOS UNIDADES
    MOVF tmins, W
    RETURN
    
TSECS_A_DISP:	    ; SEPARA REGISTER SEGUNDOS DE TIMER EN UNIDADES Y DECENAS
    MOVF tsecs, W
    MOVWF tsecs+1
    CLRF TSEC_U
    CLRF TSEC_D
    CALL DTS	    ; OBTENEMOS DECENAS
    MOVLW 10
    ADDWF tsecs+1, F
    CALL UTS	    ; OBTENEMOS UNIDADES
    MOVF tsecs, W
    RETURN
    
;===============================MAS SUBRUTINAS================================
DM:			    ; SUBRUTINAS DE OBTENCION DE DECENAS Y UNIDADES DE CADA REGISTER
    MOVLW 10
    SUBWF mins+1, W 
    MOVWF mins+1
    BANKSEL STATUS
    BTFSS STATUS, 0
    RETURN        
    INCF MIN_D, F   
    GOTO DM
UM:
    MOVF mins+1, W     
    MOVWF MIN_U
    RETURN 
    
DH:  
    MOVLW 10
    SUBWF horas+1, W 
    MOVWF horas+1
    BANKSEL STATUS
    BTFSS STATUS, 0
    RETURN        
    INCF HORA_D, F   
    GOTO DH
UH:
    MOVF horas+1, W     
    MOVWF HORA_U
    RETURN 
    
DD:
    MOVLW 10
    SUBWF dias+1, W 
    MOVWF dias+1
    BANKSEL STATUS
    BTFSS STATUS, 0
    RETURN        
    INCF DIA_D, F   
    GOTO DD
UD:
    MOVF dias+1, W
    MOVWF DIA_U
    RETURN
    
DME:
    MOVLW 10           
    SUBWF meses+1, W 
    MOVWF meses+1
    BANKSEL STATUS
    BTFSS STATUS, 0 
    RETURN          
    INCF MES_D, F   
    GOTO DME
UME:
    MOVF meses+1, W   
    MOVWF MES_U
    RETURN
    
DTM:  
    MOVLW 10
    SUBWF tmins+1, W 
    MOVWF tmins+1
    BANKSEL STATUS
    BTFSS STATUS, 0
    RETURN        
    INCF TMIN_D, F   
    GOTO DTM
UTM:
    MOVF tmins+1, W     
    MOVWF TMIN_U
    RETURN
    
DTS:  
    MOVLW 10
    SUBWF tsecs+1, W 
    MOVWF tsecs+1
    BANKSEL STATUS
    BTFSS STATUS, 0
    RETURN        
    INCF TSEC_D, F   
    GOTO DTS
UTS:
    MOVF tsecs+1, W     
    MOVWF TSEC_U
    RETURN 
    
RESET_MES:		; SUBRUTINA QUE REINICIA MES AL DEVOLVER A DÍA 1
    BANKSEL dias
    MOVLW 1
    MOVWF dias
    CALL DIAS_A_DISP
    MOVF DIA_D, W
    RETURN
  
UF_MES31:		; SUBRUTINAS DE UNDERFLOF DE MESES
    MOVLW 31
    MOVWF dias
    CALL DIAS_A_DISP
    RETURN
    
UF_MES30:
    MOVLW 30
    MOVWF dias
    CALL DIAS_A_DISP
    RETURN
    
UF_MES28:
    MOVLW 28
    MOVWF dias
    CALL DIAS_A_DISP
    RETURN			
    
;-------------------------------------------------------------------------------

ORG 200h
TABLA_DIS:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en direcci?n 02xxh
    ANDLW   0x0F		; no saltar m?s del tama?o de la tabla
    ADDWF   PCL
    ;TABLA CIRCUITO FISICO
;    RETLW   11101110B	;0
;    RETLW   01000010B	;1
;    RETLW   01011000B	;2
;    RETLW   01010110B	;3
;    RETLW   01110010B	;4
;    RETLW   00110110B	;5
;    RETLW   00111110B	;6
;    RETLW   01000010B	;7
;    RETLW   01111110B	;8
;    RETLW   01110110B	;9
    ;TABLA PROTEUS
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
    
; ----------------------subrutinas de config---------------------------
	
CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH		; I/O digitales
    
    BANKSEL TRISA
    CLRF    TRISA
    CLRF    TRISC		; PORTC como salida
    BCF	    TRISD, 0		; LED CONFIG
    BCF	    TRISD, 1		; LED ALARMA
    BSF	    PORTB, 7		; BOTON ESTADO
    BSF	    PORTB, 6		; BOTON INC 
    BSF	    PORTB, 5		; BOTON DEC 
    BSF	    PORTB, 4		; BOTON	MOD H/M D/M
    BSF	    PORTB, 3		; BOTON START/STOP 
    BCF	    PORTB, 2
    
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7	; PORTB Pull-up habilitado

    BANKSEL WPUB
    BSF	    WPUB, 7		; PORTB habilitado como Pull-up
    BSF	    WPUB, 6
    BSF	    WPUB, 5
    BSF	    WPUB, 4
    BSF	    WPUB, 3
    
    BANKSEL PORTA
    CLRF    PORTA		;Limpieza de puertos
    CLRF    PORTC
    CLRF    PORTB
    CLRF    PORTD
    
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
    BCF PS2
    BCF PS1
    BCF PS0		; PS<2:0> -> 000 PRESCALER 1 : 2

   BANKSEL TMR0	; Cambiamos de banco
    MOVLW 131
    MOVWF TMR0		; 2ms retardo
    BCF T0IF		; Limpiamos bandera de interrupci?n
    RETURN
    
    BANKSEL TMR0	; Cambiamos de banco
    MOVLW 255
    MOVWF TMR0		; 2ms retardo
    BCF T0IF		; Limpiamos bandera de interrupci?n
    RETURN
    
CONFIG_TMR1:
   BANKSEL T1CON	    ; Cambiamos a banco 00
   BCF	    TMR1CS	    ; Reloj interno
   BCF	    T1OSCEN	    ; Apagamos LP
   BCF T1CON, 5
   BSF T1CON, 4		    ;PRESCALER 2
   
   BCF	    TMR1GE	    ; TMR1 siempre contando
   BSF	    TMR1ON	    ; Encendemos TMR1
   
   MOVLW 00001011B
   MOVWF TMR1H 
   MOVLW 11011100B
   MOVWF TMR1L         ;1 SEGUNDO
   RETURN
   
CONFIG_TMR2:
   BANKSEL PR2		    ; Cambiamos a banco 01
    MOVLW   122		    ; Valor para interrupciones cada 500ms
    MOVWF   PR2		    ; Cargamos literal a PR2
    
    BANKSEL T2CON	    ; Cambiamos a banco 00
    BSF	    T2CKPS1	    ; Prescaler 1:16
    BSF	    T2CKPS0
    
    BSF	    TOUTPS3	    ;Postscaler 1:16
    BSF	    TOUTPS2
    BSF	    TOUTPS1
    BSF	    TOUTPS0
    
    BSF	    TMR2ON	    ; Encendemos TMR2
    RETURN
   
   RETURN
    
    
CONFIG_INT:
    BANKSEL PIE1	    ; Cambiamos a banco 01
    BSF	    TMR1IE	    ; Habilitamos int. TMR1
    BSF	    TMR2IE	    ; Habilitamos int. TMR2
    
    BANKSEL INTCON	    ; Cambiamos a banco 00
    BSF	    PEIE	    ; Habilitamos int. perifericos
    BSF	    GIE		    ; Habilitamos int. globales
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de TMR0
    BCF	    TMR1IF	    ; Limpiamos bandera de TMR1
    BCF	    TMR2IF	    ; Limpiamos bandera de TMR2
    
    BANKSEL IOCB
    BSF IOCB7
    BSF IOCB6
    BSF IOCB5
    BSF IOCB4
    BSF IOCB3
    RETURN
    
LIMPIAR:		    ; LIMPIEZA DE VARIABLES
   BCF STATUS, 6
   BCF STATUS, 5 ;BANCO 0
   CLRF PORTA
   CLRF PORTC
   CLRF PORTB
   CLRF	PORTD
   CLRF SEGS
   CLRF MIN_U
   CLRF MIN_D
   CLRF HORA_U
   CLRF HORA_D
   CLRF DIS1
   CLRF DIS2
   CLRF DIS3
   CLRF DIS4
   BCF T0IF 
   BCF TMR1IF 
   BCF TMR1IF 
   RETURN
    
END
    