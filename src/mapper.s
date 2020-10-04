;
; UNROM driver for NES
; Copyright 2011-2015 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

.include "mmc1.inc"  ; implements a subset of the same interface
.import nmi_handler, reset_handler, irq_handler, bankcall_table

.segment "INESHDR"
  .byt "NES", $1A  ; these four bytes identify a file as an NES ROM
  .byt 4     ; size of PRG, in 16384 byte units
  .byt 0     ; size of CHR, in 8192 byte units
  .byt (28&$0f << 4) + 1 + 2 ; vertical, battery
  .byt (28&$f0) + %1000
  .byt 0     ; extended mapper size
  .byt 0     ; extended ROM sizes
  .byt $00   ; 0KB battery backed RAM
  .byt $09   ; 32KB CHR RAM
  .byt 0     ; NTSC
  .byt 0     ; not VS System

.segment "ZEROPAGE"
lastPRGBank: .res 1
lastBankMode: .res 1
bankcallsaveA: .res 1

.segment "CODE"
;;
; Changes $8000-$BFFF to point to a 16384 byte chunk of PRG ROM
; starting at $4000 * A.
.proc setPRGBank
  ldy #$01
  sty $5000 ; Register select
  sta lastPRGBank
  sta $8000 ; Register value
  rts
.endproc

; Inter-bank method calling system.  There is a table of up to 85
; different methods that can be called from a different PRG bank.
; Typical usage:
;   ldx #move_character
;   jsr bankcall
.proc bankcall
  sta bankcallsaveA
  lda lastPRGBank
  pha
  lda bankcall_table+2,x
  jsr setPRGBank
  lda bankcall_table+1,x
  pha
  lda bankcall_table,x
  pha
  lda bankcallsaveA
  rts
.endproc

; Functions in the bankcall_table MUST NOT exit with 'rts'.
; Instead, they MUST exit with 'jmp bankrts'.
.proc bankrts
  sta bankcallsaveA
  pla
  jsr setPRGBank
  lda bankcallsaveA
  rts
.endproc



.macro resetstub_in segname
.segment segname
.scope
resetstub_entry:
  ; Mesen doesn't seem to initialize the outer bank correctly to put the last 16KB at $c000 as expected
  sei                ; 1
  lda #$81           ; 3
  sta $5000          ; 6
  lda #1             ; 8
  sta $8000          ; 11
  jmp reset_handler  ; 14
  .addr nmi_handler, resetstub_entry, irq_handler ; Must start at FFFA
.endscope
.endmacro

.segment "CODE"
resetstub_in "STUB00"
resetstub_in "STUB01"
resetstub_in "STUB02"
resetstub_in "STUB03"
