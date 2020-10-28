.include "nes.inc"
.include "mapper.inc"
.include "global.inc"

.segment "CODE"

; A = level number
.export DecompressLevel
.proc DecompressLevel
  sta LevelNumber

  ; Probably have it require that rendering be off first?
  jsr WaitVblank
  lda #0
  sta PPUMASK
  setCHRBankMacro 3

  ; Clear out the level buffer first
  lda #0
  sta PPUADDR
  sta PPUADDR
  tax
  ldy #(4096/256)
: sta PPUDATA
  inx
  bne :-
  dey
  bne :-




  setCHRBankMacro 0
  rts
.endproc
