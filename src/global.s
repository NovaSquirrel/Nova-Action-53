.include "nes.inc"
.include "mapper.inc"
.include "global.inc"
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
.import  BlockPalette, BlockFlags

.code

; Updates PPUSCROLL and PPUCTRL to account for ScrollX
; locals: 0
.export UpdateScrollRegister
.proc UpdateScrollRegister
  lda ScrollX+1
  sta 0
  lda ScrollX
  .repeat 4
    lsr 0
    ror
  .endrep
  sta PPUSCROLL
  lda #0
  sta PPUSCROLL
;  lda PlaceBlockInLevel ; if in block placing mode, sprites use background tiles
;  and #%01000000
;  bne BGSprites
  lda 0
  and #1 ; bit 0 is most significant bit of scroll
  ora #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_1000
  sta PPUCTRL
  rts
BGSprites:
  lda 0
  and #1 ; bit 0 is most significant bit of scroll
  ora #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_0000
  sta PPUCTRL
  rts
.endproc
