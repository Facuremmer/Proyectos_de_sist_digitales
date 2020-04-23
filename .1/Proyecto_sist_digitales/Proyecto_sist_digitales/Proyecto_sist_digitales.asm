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
.org 0x016
			RJMP DAC_TC1_COMPA
			RJMP DAC_TC1_COMPB
.org 0X02A
			RJMP ADC_RTI

.org 0x34 
			RETI
INICIO: 
		CONFIG_SP							
	  
;-----------------------------------------
;--------Configuración del ADC------------
	    LDI R16, 0b0000_0000 
		OUT DDRC, R16 ;Definimos todo el puerto A del ADC como entrada
		LDI R16, 0b111_1100; Establecemos R-PULL/UP por seguridad en todos menos en ADC1 y ADC0.
		OUT PORTC, R16
		LDI R16, (0<<REFS1)|(1<<REFS0)|(0<<ADLAR)|(0<<MUX3)|(0<<MUX2)|(0<<MUX1)|(0<<MUX0) 
		STS ADMUX, R16 ;Voltaje de referencia del micro, y utilizaremos el canal 0
		;Habilitamos el autodisparo de int por contador, prestacalor en 64:125khz, habilitacion del adc, 
		LDI R16, (1<<ADEN)|(0<<ADSC)|(1<<ADATE)|(0<<ADIF)|(1<<ADIE)|(1<<ADPS2)|(1<<ADPS2)|(0<<ADPS2)
		STS ADCSRA, R16 ;habilitamos el adc
		LDI R16, (0<<ACME)|(0<<ADTS2)|(0<<ADTS1)|(0<<ADTS0) ;Deshabilitacion del multiplexor, fuente autodisparo modo libre
		STS ADCSRB, R16 ;habilitamos el adc
		LDI R16, (0<<ADC5D)|(0<<ADC4D)|(0<<ADC3D)|(0<<ADC2D)|(1<<ADC1D)|(1<<ADC0D)
		STS DIDR0, R16 ;deshabilitamos el buffer de entrada en A0 
;-----------------------------------------
;----------Configuracion del DAC----------	
		LDI R16, 0b0000_0110 ;Configuramos PB1 y PB2 como salida, el resto como entrada 	
		OUT DDRB, R16
		LDI R16, 0b1111_1001; Establecemos R-PULL/UP por seguridad en el resto de los pines.
		OUT PORTB, R16
		LDS R16,(1<<COM1A1)|(0<<COM1A0)|(1<<COM1B1)|(0<<COM1B0)|(1<<WGM11)|(1<<WGM10); Establecemos los comparadores del TC1 que limpien OC1n en comparacion igual y seteen en BOTTOM 
		STS TCCR1A, R16															; y configuramos el TC1 con generador de PWM rápido de 10 bits.
		CLR R16 ; Establecemos el valor de 0CR1A con el valor 0 por seguridad.
		STS OCR1AL, R16
		STS OCR1AH, R16
		LDS R16, (0<<ICNC1)|(0<<ICES1)|(0<<WGM13)|(1<<WGM12)|(0<<CS12)|(0<<CS11)|(1<<CS10); Terminamos de configurar el PWM y configuramos el preescalador en 1 fTC1= 16MHz/(1*1024) =15,625KHz 
		STS TCCR1B, R16																    
		CLR R16 ; Establecemos el valor de 0CR1B con el valor 0 por seguridad.
		STS OCR1BL, R16 
		STS OCR1BH, R16
		CLR R16				;Deshabilitamos la comparación de salida forzada por seguridad
		STS TCCR1C, R16
		LDI R16, (0<<ICIE1)|(1<<OCIE1B)|(1<<OCIE1A)|(0<<TOIE1); Habilitamos la interrupcion por comparación exitosa de OCR1A/B.
		STS TIMSK1, R16
		
		SEI  


		LDI R16, ADCSRA							;Cargamos el valor del registro ADCSRA a R16.
		ANDI R16, (1<<ADSC)						;Iniciamos una nueva conversión, enmascarando ADCSRA y seteando ADSC.
		STS ADCSRA, R16							; Guardamos en ADCSRA.
Bucle:
		CALL Retardo_20ms						; Llamamos a rutina de retardo de 20ms.
		RJMP Bucle								; retornamos a la etiqueta.


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
		STS LOW(V_VAL_RAM), R16						; Guarda el valor del registro de datos del ADC en la RAM.
		STS HIGH(V_VAL_RAM), R16						; Guarda el valor del registro de datos del ADC en la RAM.
		LDI R18, 1								; Carga en R18 el canal deseado(LDI R18,(CANAL DESEADO)).
		RJMP SalidaADC_RTI						; Salta a la etiqueta SalidaADC_RTI.

;------ Proceso de guardado de corriente en RAM ------
I_GUARDAR_RAM:									; Etiqueta
		LDS R16, ADCL							; Guarda la parte baja (ADCL) del registro de datos del ADC en R16.
		LDS R16, ADCH							; Guarda la parte alta (ADCH) del registro de datos del ADC en R16.
		STS LOW(I_VAL_RAM), R16						; Guarda el valor del registro de datos del ADC en la RAM.
		STS HIGH(I_VAL_RAM), R16						; Guarda el valor del registro de datos del ADC en la RAM.
Salto1:																						
		LDI R18, 0								;Elegimos el canal deseado(LDI R18,(CANAL DESEADO)).		

;------ Proceso de salida de la RTI------
SalidaADC_RTI:									; Etiqueta
		ADD R17, R18							; Suma a R17 el valor de R18 (CANAL DESEADO).
		STS ADMUX, R17							; Guarda el valor de R17 en ADMUX.
;----------Devolvemos de la pila----------
		POP R18									; Devuelve de la pila el valor de R18.
		POP R17									; Devuelve de la pila el valor de R17.
		POP R16									; Devuelve de la pila el valor de SREG a R16.
		OUT SREG,R16							; Carga en Sreg el valor de R16.
		POP R16									; Devuelve de la pila el valor de R16.
	RETI			
;-----------------------------------------
;---------- FIN DE RTI DEL ADC -----------
;-----------------------------------------



;-----------------------------------------
;-------- RTI DEL DAC_TC1_COMP1A ---------
;-----------------------------------------
DAC_TC1_COMPA:

;-------------- Guardamos en la pila -------------- 
		PUSH	R16;		Guarda en la pila el valor de R16.
		IN		R16, SREG;	Carga en R16 el valor del registro de estado.
		PUSH	R16;		Guarda en la pila el valor de R16.
;---------Establecemos el nuevo valor de OCR1A----------
		LDS R16, LOW(V_VAL_RAM); Cargamos el valor de tension de V_VAL_RAM en R16.
		LDS R16, HIGH(V_VAL_RAM); Cargamos el valor de tension de V_VAL_RAM en R16.
		STS OCR1AL, R16;	Guardamos el valor de la parte baja de R16.
		STS OCR1AH, R16;	Guardamos el valor de la parte alta de R16.
;----------Devolvemos de la pila----------
		POP R16;			Devuelve de la pila el valor de SREG a R16.
		OUT SREG,R16;		Carga en Sreg el valor de R16.
		POP R16;			Devuelve de la pila el valor de R16.
	RETI	
;-----------------------------------------
;-------------- FIN DE RTI ---------------
;-----------------------------------------



;-----------------------------------------
;------- RTI DEL DAC_TC1_COMP1B ---------- 
;-----------------------------------------
DAC_TC1_COMPB:

;-------------- Guardamos en la pila -------------- 
		PUSH	R16;		Guarda en la pila el valor de R16.
		IN		R16, SREG;	Carga en R16 el valor del registro de estado.
		PUSH	R16;		Guarda en la pila el valor de R16.
;---------Establecemos el nuevo valor de OCR1A----------
		LDS R16, LOW(I_VAL_RAM); Cargamos el valor de corriente de I_VAL_RAM en R16.
		LDS R16, HIGH(I_VAL_RAM); Cargamos el valor de corriente de I_VAL_RAM en R16.
		STS OCR1BL, R16;	Guardamos el valor de la parte baja de R16.
		STS OCR1BH, R16;	Guardamos el valor de la parte alta de R16.
;----------Devolvemos de la pila----------
		POP R16;			Devuelve de la pila el valor de SREG a R16.
		OUT SREG,R16;		Carga en Sreg el valor de R16.
		POP R16;			Devuelve de la pila el valor de R16.
	RETI	
;-----------------------------------------
;-------------- FIN DE RTI ---------------
;-----------------------------------------



; ============================= 
;    delay loop generator 
;     320000 cycles:
; ----------------------------- 
Retardo_20ms:
          ldi  R20, $26
WGLOOP0:  ldi  R21, $17
WGLOOP1:  ldi  R22, $79
WGLOOP2:  dec  R22
          brne WGLOOP2
          dec  R21
          brne WGLOOP1
          dec  R20
          brne WGLOOP0
; ----------------------------- 
; delaying 2 cycles:
          nop
          nop
	ret
; ============================= 