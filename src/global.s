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

; Sets LevelBlockPtr to the start of a given column in the level, then reads a specific row
; input: A (column), Y (row)
; output: LevelBlockPtr is set, also A = block at column,row
.export GetLevelColumnPtr
.proc GetLevelColumnPtr
  pha
  ; Check and make sure it's actually in range!
  lda #0
  sta LevelBlockPtr+1
  pla
  and #31
  ora #%01100000 ; Makes sure the resulting pointer is $6xx or $7ff
  .repeat 4
    asl
    rol LevelBlockPtr+1
  .endrep
  sta LevelBlockPtr

  lda (LevelBlockPtr),y
  rts
.endproc

; quick way to convert the numbers 0 to 99 from binary to decimal
.export BCD99
.proc BCD99
  .byt $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
  .byt $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39
  .byt $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $50, $51, $52, $53, $54, $55, $56, $57, $58, $59
  .byt $60, $61, $62, $63, $64, $65, $66, $67, $68, $69, $70, $71, $72, $73, $74, $75, $76, $77, $78, $79
  .byt $80, $81, $82, $83, $84, $85, $86, $87, $88, $89, $90, $91, $92, $93, $94, $95, $96, $97, $98, $99
.endproc
