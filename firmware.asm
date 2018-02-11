; Part 7 - memory test and LCD screen
;
; ROM is at C000 - FFFF
; Hardware devices start at 8000:
;   8000 - 6522 (RS0 to RS3 are wired to A0 to A3)
;   8100 - LCD screen (RS pin is wired to A0)
;   8200 - unassigned
;   8300 - unassigned
;   8400 - unassigned
;   8500 - unassigned
;   8600 - unassigned
;   8700 - unassigned
; RAM is at 0000 - 7FFF
; ROM board is wired for full 32K access (from 8000 to FFFF) but select logic
; only works for last 16K of that. So ROM image must contain full 32K, but be aware
; that first 16K of that is placeholder (for the moment).
; I've done it this way so that it'll be easy to use the earlier 16K when I need the space
; (and can be bothered to make a new address decoder board).

via_base = &8000
via_iorb = via_base
via_ddrb = via_base + 2

lcd_base = &8100
lcd_r0 = lcd_base
lcd_r1 = lcd_base + 1

zp_memtestlocation = &80	; arbitrary byte in RAM we'll write to to check that the RAM hardware exists
zp_msgbase = &80			; where the address of the string to print will be written (and the next byte, too)

ORG &8000
	EQUS "This 16K isn't being used yet. Just placeholder for the moment."


ORG &C000

.start_here
				sei				; disable interrupts just in case
				cld				; clear decimal flag
				
				lda #&FF:sta via_ddrb		; set all portb as outputs
 				ldx #&00:stx via_iorb		; X = 0
			
				; To do any comprehensive RAM test requires ZP and a stack.
				; So to begin with, we do a basic RAM test (just write some values to
				; RAM and check they can be read back OK).
				; If that fails, we lockup. If it passes, we do a more thorough RAM test.
			
				lda #0
				sta zp_memtestlocation		; store 0 in RAM
				lda #&FF					; trash A, just to be certain
				lda zp_memtestlocation		; now load A back from RAM
				cmp #0						; is it 0?
				bne simpleramtestfailed		; no, so print fail message
			
				lda #&55
				sta zp_memtestlocation		; store &55 in RAM
				lda #&FF					; trash A, just to be certain
				lda zp_memtestlocation		; now load A back from RAM
				cmp #&55					; is it &55?
				bne simpleramtestfailed		; no, so print fail message
			
				; if we get here, then the simple tests passed.
				; So from this point, we'll assume we have ZP and stack.
				beq simpleramtestpassed
				
				; otherwise, we failed - so just loop, flashing portB on and off
			
.simpleramtestfailed
				; for failure, we'll toggle pins on port B all on and then off
				ldx #%11111111:stx via_iorb
				ldx #%00000000:stx via_iorb
				jmp simpleramtestfailed	
			
.simpleramtestpassed
				; if we get here, then the simple RAM test passed.
				; So we'll assume we have ZP and stack.
				
				ldx #&FF:txs			; reset stack to where it should be (&1FF)

				jsr lcdinit
				jsr lcdclear
				
				; print welcome message to LCD ...
				lda #welcomemessage MOD 256:sta zp_msgbase
				lda #welcomemessage DIV 256:sta zp_msgbase + 1
				JSR lcdstring
				
				; (memtest is TODO, when I'm in the mood)
				
.finalloophere
				; for success, we'll toggle pins on port B alternately
				ldx #%10101010:stx via_iorb
				ldx #%01010101:stx via_iorb
				jmp finalloophere
			
.welcomemessage					EQUS "Toastrack 6502 32K", 0

; ------------------------------------------------------------------------------
; LCD routines

; waits until LCD screen reports that it is ready for next byte
.lcdbusy
				pha					; push A to stack
.lcdbusy0		lda lcd_r0			; load from LCD r0 (top bit is "busy" flag, other bits are current address of cursor)
				and #&80			; filter to just top bit
				bne lcdbusy0		; if set, then screen is still busy ... so recheck
				pla					; pull A from stack
				rts

; initialise the display
.lcdinit		ldx #$04			; we send the initialise command 4 times, just in case
									; it's been left in a funny half-state
.lcdinit0		lda #$38:sta lcd_r0	; function set: 8 bit, 2 lines, 5x7
				jsr lcdbusy			; wait for it to finish
				dex
				bne lcdinit0
				lda #$06:sta lcd_r0	; entry mode set: increment, no shift
				jsr lcdbusy			; wait for it to finish
				lda #$0E:sta lcd_r0	; display on, cursor on, blink off
			
				jsr lcdbusy			; wait for it to finish
				lda #$01:sta lcd_r0	; clear display
				jsr lcdbusy			; wait for it to finish
				lda #$80:sta lcd_r0	; DDRAM address set: $00
				jsr lcdbusy			; wait for it to finish
				rts

; clear LCD display and home the cursor
.lcdclear		pha						; push A
				lda #$01:sta lcd_r0		; store 1 in LCD r0 (the command register)
				jsr lcdbusy				; wait for it to finish
				lda #$80:sta lcd_r0		; store &80 in command register
				jsr lcdbusy				; wait for it to finish
				pla						; pull A
				rts

; *** Print character on LCD (40 character)
; registers preserved
.lcdprintchar	pha
				sta lcd_r1			; output the character
				jsr lcdbusy			; wait for it to finish
				lda lcd_r0			; get current DDRAM address
				and #$7F			; ensure busy flag is filtered out (though to be honest, it's bound to be)
				cmp #$14			; wrap from pos $13 (line 1 char 20)...
				bne lcdprintchar0
				lda #$C0:sta lcd_r0	; ...to $40 (line 2 char 1)
				jsr lcdbusy			; wait for it to finish
				
.lcdprintchar0	pla
				rts

; print a zero-terminated string to the screen.
; Address of string should have been stored in zp_msgbase and zp_msgbase+1.
.lcdstring		pha:tya:pha			; push A and Y onto stack
				ldy #$00
.lcdstr0		lda (zp_msgbase), Y
				beq lcdstr1
				jsr lcdprintchar
				iny
				bne lcdstr0
.lcdstr1		pla:tay:pla			; restore Y and then A from stack
				rts

ORG &FFFA
				equw      start_here       ; NMI address (not used at the moment)
				equw      start_here       ; RESET address
				equw      start_here       ; IRQ address (not used at the moment)


