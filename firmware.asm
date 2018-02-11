; Firmware / OS for DIY6502 (part 5).
; (see http://danceswithferrets.org/geekblog/?p=656)
;
; ROM is at C000 - FFFF
; RAM is at 0000 - 7FFF
; 6522 VIA is at 8000
;

via_base = &8000
via_iorb = via_base
via_ddrb = via_base + 2

zp_memtestlocation = &80

ORG &8000
	EQUS "This 16K isn't being used yet. Just placeholder for the moment."

ORG &C000
.start_here
				sei				; disable interrupts just in case
				cld				; clear decimal flag

				lda #&FF:sta via_ddrb		; set all portb as outputs
 				ldx #&00:stx via_iorb		; X = 0

				; very simple write-and-then-read-back tests ...

				lda #0
				sta zp_memtestlocation		; store 0 in RAM
				lda #&FF					; trash A, just to be certain
				lda zp_memtestlocation		; now load A back from RAM
				cmp #0						; is it 0?
				bne simpleramtestfailed		; no
			
				lda #&55
				sta zp_memtestlocation		; store &55 in RAM
				lda #&FF					; trash A, just to be certain
				lda zp_memtestlocation		; now load A back from RAM
				cmp #&55					; is it &55?
				bne simpleramtestfailed		; no
			
				; if we get here, then the simple tests passed.
				beq simpleramtestpassed
			
.simpleramtestfailed
				; for failure, we'll toggle ALL pins on port B
				ldx #&FF:stx via_iorb ; %11111111
				ldx #&00:stx via_iorb ; %00000000
				jmp simpleramtestfailed
				
.simpleramtestpassed
				; for pass, we'll alternate even and odd pins on port B
				ldx #&aa:stx via_iorb ; %10101010
				ldx #&55:stx via_iorb ; %01010101
				jmp simpleramtestpassed

ORG &FFFA
				equw      start_here       ; NMI address (not used at the moment)
				equw      start_here       ; RESET address
				equw      start_here       ; IRQ address (not used at the moment)


