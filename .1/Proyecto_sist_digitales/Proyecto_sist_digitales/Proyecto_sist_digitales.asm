
; Replace with your application code
.macro CONFIG_SP													
		LDI R16,	LOW(RAMEND)					; Se carga el valor de la parte baja de la ram en el registro 16.
		OUT SPL,	R16							; Se carga en la parte baja de la pila el valor del registro 16.	
		LDI R16,	HIGH(RAMEND)				; Se carga el valor de la parte alta de la ram en el registro 16.
		OUT SPH,	R16							; Se carga en la parte alta de la pila el valor del registro 16.	
.endmacro	

; Definimos las variables de la RAM que usaremos
.dseg						
.org 0x100
	V_VAL_RAM:									; Definimos el lugar de la RAM donde se guarda la tension del ADC
			.byte 2								; Usaremos dos bytes porque se utilizan 10 bits de resolución
	I_VAL_RAM:									; Definimos el lugar de la RAM donde se guarda la corriente del ADC
			.byte 2								; Usaremos dos bytes porque se utilizan 10 bits de resolución

.cseg 
.org 0x00
			RJMP INICIO

.org 0X02A
			RJMP ADC_RTI

.org 0x34 
			RETI
INICIO: 
		CONFIG_SP							
	    LDI R16, 0b0000_0000 
		OUT DDRC, R16 ;Definimos todo el puerto A del ADC como entrada
		LDI R16, 0b0000_0000
		OUT PORTC, R16
		LDI R16, (0<<REFS1)|(0<<REFS0)|(0<<ADLAR)|(0<<MUX3)|(0<<MUX2)|(0<<MUX1)|(1<<MUX0) 
		STS ADMUX, R16 ;Voltaje de referencia del micro, y utilizaremos el canal 0
		;Habilitamos el autodisparo de int por contador, prestacalor en 64:125khz, habilitacion del adc, 
		LDI R16, (1<<ADEN)|(0<<ADSC)|(1<<ADATE)|(0<<ADIF)|(1<<ADIE)|(1<<ADPS2)|(1<<ADPS2)|(0<<ADPS2)
		STS ADCSRA, R16 ;habilitamos el adc
		LDI R16, (0<<ACME)|(0<<ADTS2)|(0<<ADTS1)|(0<<ADTS0) ;Deshabilitacion del multiplexor, fuente autodisparo modo libre
		STS ADCSRB, R16 ;habilitamos el adc
		LDI R16, (0<<ADC5D)|(0<<ADC4D)|(0<<ADC3D)|(0<<ADC2D)|(1<<ADC1D)|(1<<ADC0D)
		STS DIDR0, R16 ;deshabilitamos el buffer de entrada en A0 
		
		SEI  

Bucle:
		LDS R16, ADMUX								; Se inicia seteando el bit de inicio de conversión 
;-----------------------------------------
;-------------- RTI DEL ADC -------------- 
;-----------------------------------------
ADC_RTI:

;-------------- Guardamos en la pila -------------- 
		PUSH	R16								; Guarda en la pila el valor de R16.
		IN		R16, SREG						; Carga en R16 el valor del registro de estado.
		PUSH	R16								; Guarda en la pila el valor de R16.
		PUSH	R17								; Guarda en la pila el valor de R17.
		PUSH	R18								; Guarda en la pila el valor de R17.
		LDS		R16, ADMUX						; Guarda en R16 el valor de ADMUX.
		LDS		R17, ADMUX						; Guarda en R17 el valor de ADMUX.
		ANDI	R16, 0x0F						; Enmascara la parte baja de AMUX.
		ANDI	R17, 0xF0						; Enmascara la parte alta de AMUX.		
		CPI		R16, 0							; compara si R16 está en 0 (ADC0).
		BREQ    V_GUARDAR_RAM					; Salta a V_GUARDAR_RAM si la comparación es exitosa.
		CPI		R16, 1 							; Sino, compara si R16 está en 1 (ADC1).
		BREQ	I_GUARDAR_RAM					; Salta a I_GUARDAR_RAM si la comparación es exitosa.
		RJMP	Salto1							; Si no lo es, salta a la etiqueta Salto1, esta etiqueta se utiliza 
												; para recuperar el proceso de los ADC, si en algun momento falla.

;------- Proceso de guardado de tensión en RAM -------
V_GUARDAR_RAM:									; Etiqueta
		LDS R16, ADCL							; Guarda la parte baja (ADCL) del registro de datos del ADC en R16. 
		LDS R16, ADCH							; Guarda la parte alta (ADCH) del registro de datos del ADC en R16.
		STS V_VAL_RAM, R16						; Guarda el valor del registro de datos del ADC en la RAM.
		LDI R18, 1								; Carga en R18 el canal deseado(LDI R18,(CANAL DESEADO)).
		RJMP SalidaADC_RTI						; Salta a la etiqueta SalidaADC_RTI.

;------ Proceso de guardado de corriente en RAM ------
I_GUARDAR_RAM:									; Etiqueta
		LDS R16, ADCL							; Guarda la parte baja (ADCL) del registro de datos del ADC en R16.
		LDS R16, ADCH							; Guarda la parte alta (ADCH) del registro de datos del ADC en R16.
		STS I_VAL_RAM, R16						; Guarda el valor del registro de datos del ADC en la RAM.

Salto1:																						
		LDI R18, 0								;Elegimos el canal deseado(LDI R18,(CANAL DESEADO)).		

;------ Proceso de salida de la RTI------
SalidaADC_RTI:									; Etiqueta
		ADD R17, R18							; Suma a R17 el valor de R18 (CANAL DESEADO).
		STS ADMUX, R17							; Guarda el valor de R17 en ADMUX.
		POP R18									; Devuelve de la pila el valor de R18.
		POP R17									; Devuelve de la pila el valor de R17.
		POP R16									; Devuelve de la pila el valor de SREG a R16.
		OUT SREG,R16							; Carga en Sreg el valor de R16.
		POP R16									; Devuelve de la pila el valor de R16.
	RETI			
;-----------------------------------------
;---------- FIN DE RTI DEL ADC -----------
;-----------------------------------------



SDELAY:
	NOP
	NOP
	RET

DELAY_100us:
	PUSH	R19
	LDI		R19,60
DR0:	
	CALL	SDELAY
	DEC		R19
	BRNE	DR0
	POP		R19
	RET
;-------------------------------------------------------
DELAY_2ms:
	PUSH	R19
	LDI		R19,20
LDR0:	
	CALL	DELAY_100US
	DEC		R19
	BRNE	LDR0
	POP		R19
	RET


