.include "nes.inc"
.include "mapper.inc"
.include "global.inc"
.importzp FirstSingleType, FirstRectType, FirstWideType, FirstTallType, FirstBigRectType
.import SingleTypeList, SimpleRectList, LineTypeList
.import LevelPointerList
.import BlockAutotile, BlockAutotileRoutine, BlockFlags

.segment "CODE"

; A = level number
.export LoadLevel
.proc LoadLevel
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

  ; Make the level data accessible
  lda #<.bank(LevelPointerList)
  jsr setPRGBank
  lda LevelNumber
  asl
  lda LevelPointerList+0,x
  sta LevelHeaderPointer+0
  lda LevelPointerList+1,x
  sta LevelHeaderPointer+1

  ;----------------------------------------------
  ; Parse the header
  ldy #0
  lda (LevelHeaderPointer),y
  iny
  lda (LevelHeaderPointer),y
  iny
  sta PlayerPXH
  lda (LevelHeaderPointer),y
  iny
  and #15 ; Also has width in upper nybble
  sta PlayerPYH
  ldx #0
: lda (LevelHeaderPointer),y
  iny
  sta SpriteTileSlots,x
  inx
  cpx #10
  bne :-
  ; TODO: resource list maybe?

  ;----------------------------------------------
  ; Decode the level itself
  lda #0
  sta LevelDecodeXPos
LevelCommandLoop:
  ldy #0
  lda (LevelDecodePointer),y
  tax
  cmp #$f0 ; Special command
  bcs SpecialCommand
  cmp #FirstBigRectType
  bcs BigRectType
  cmp #FirstTallType
  bcs TallType
  cmp #FirstWideType
  bcs WideType
  cmp #FirstRectType
  bcs RectType
  ; Otherwise it's a single block type
  SingleType:
    lda SingleTypeList-FirstSingleType,x
    jsr GetPosition
    jsr SetPPUPointer
    lda DecodeObjectBlock
    sta PPUDATA
    jsr IncreaseDecodePointerByY
    jmp LevelCommandLoop
  BigRectType:
    sub #FirstBigRectType
    jsr LineTypeBaseAndPosition
    jsr LineTypeGetHeightAndBlock
    lda (LevelDecodePointer),y
    sta DecodeObjectWidth
    iny
    bne CreateRectangle ; Unconditional? Y should be 3

  TallType:
    sub #FirstTallType
    jsr LineTypeBaseAndPosition
    jsr LineTypeGetHeightAndBlock
    lda #0
    sta DecodeObjectWidth
    bpl CreateRectangle ; Unconditional

  WideType:
    sub #FirstWideType
    jsr LineTypeBaseAndPosition
    jsr LineTypeGetHeightAndBlock
    lda DecodeObjectHeight
    sta DecodeObjectWidth
    lda #0
    sta DecodeObjectHeight
    bpl CreateRectangle ; Unconditional

  RectType:
    lda SimpleRectList-FirstRectType,x
    jsr GetPosition
    lda (LevelDecodePointer),y
    lsr
    lsr
    lsr
    lsr
    sta DecodeObjectWidth
    lda (LevelDecodePointer),y
    and #15
    sta DecodeObjectHeight
    iny
    bpl CreateRectangle ; Unconditional

  SpecialCommand:
    inc LevelDecodePointer+0
    bne :+
      inc LevelDecodePointer+1
    :
    and #15
    tax
    lda SpecialCommandHi,x
    pha
    lda SpecialCommandLo,x
    pha
    rts

  CreateRectangle:
    jsr IncreaseDecodePointerByY
    lda LevelDecodeXPos
    pha
  @ColumnLoop:
    jsr SetPPUPointer
    ldy DecodeObjectHeight
    lda DecodeObjectBlock
  : sta PPUDATA
    dey
    bpl :-
    dec DecodeObjectWidth
    bmi @Done
    inc LevelDecodeXPos
    bne @ColumnLoop ; Unconditional-ish
  @Done:
    pla
    sta LevelDecodeXPos
    jmp LevelCommandLoop

; Special commands control the level decompression itself or add metadata
SpecialCommandLo:
  .lobytes SpecialFinished-1, SpecialSetX-1, SpecialMinus16-1, SpecialPlus16-1
SpecialCommandHi:
  .hibytes SpecialFinished-1, SpecialSetX-1, SpecialMinus16-1, SpecialPlus16-1

; Set the current X position to an arbitrary value
SpecialSetX:
  iny
  lda (LevelDecodePointer),y
  sta LevelDecodeXPos
  inc LevelDecodePointer+0
  bne :+
    inc LevelDecodePointer+1
  :
  jmp LevelCommandLoop

; Move the current X position back 16 blocks
SpecialMinus16:
  lda LevelDecodeXPos
  sub #16
  sta LevelDecodeXPos
  jmp LevelCommandLoop

; Move the current X position ahead 16 blocks
SpecialPlus16:
  lda LevelDecodeXPos
  add #16
  sta LevelDecodeXPos
  jmp LevelCommandLoop

; Update LevelDecodePointer now that a command has been fully read
IncreaseDecodePointerByY:
  tya
  add LevelDecodePointer
  sta LevelDecodePointer
  bcc :+
    inc LevelDecodePointer+1
  :
  rts

;Point PPUADDR at a particular row and column in the level
SetPPUPointer:
  lda #0
  sta 0
  lda LevelDecodeXPos
  asl
  rol 0
  asl
  rol 0
  asl
  rol 0
  asl
  rol 0
  pha
  lda 0
  sta PPUADDR
  pla
  ora DecodeObjectY
  sta PPUADDR
  rts

; For line types (Wide/Tall/BigRectangle) finish getting the block type, and get the height
; Wide will need to move the height over to the width
LineTypeGetHeightAndBlock:
  lda (LevelDecodePointer),y
  lsr
  lsr
  lsr
  lsr
  sta DecodeObjectHeight
  lda (LevelDecodePointer),y
  and #15
  ora DecodeObjectBlock ; Currently holding a base temporarily
  tax
  lda LineTypeList,x
  sta DecodeObjectBlock
  iny
  rts

; Multiply the base by 16 and then get the position byte
LineTypeBaseAndPosition:
  asl
  asl
  asl
  asl
; Get and parse the position byte
GetPosition:
  sta DecodeObjectBlock
  iny
  lda (LevelDecodePointer),y ; read XY byte too
  lsr ; get X nybble only
  lsr
  lsr
  lsr
  add LevelDecodeXPos
  sta LevelDecodeXPos
  lda (LevelDecodePointer),y ; reread - rereading seems faster than PHA PLA?
  and #15
  sta DecodeObjectY
  iny ; Y = parameter, if there is one
  rts
.endproc

SpecialFinished:
.proc LevelAutotile
CurrentScreen = TouchTemp
ScreenBuffer = LevelCache+16
HasAutotile = $20

  ; Run the autotiling step now
  lda #<.bank(BlockAutotile)
  jsr setPRGBank

  lda #0
  sta CurrentScreen
ScreenLoop:
  ldx CurrentScreen
  ; assert(0)
  dex
  stx PPUADDR
  lda #$f0 ; Go back one column
  sta PPUADDR
  bit PPUDATA ; Read once to work around the $2007 read delay thing

  ; Read a screen
  ldx #0
: lda PPUDATA
  sta LevelCache,x
  inx
  bne :-
  ; Read two columns too
: lda PPUDATA
  sta LevelCache2,x
  inx
  cpx #32
  bne :-

  ; Process a screen
  ldx #0
ProcessLoop:
  ldy ScreenBuffer,x
  lda BlockFlags,y
  and #HasAutotile
  beq @NotAutotile
  jsr CallAutotile
@NotAutotile:
  inx
  bne ProcessLoop

  ; Write back a screen
  lda CurrentScreen
  sta PPUADDR
  lda #0
  sta PPUADDR
  ldx #0
: lda ScreenBuffer,x
  sta PPUDATA
  inx
  bne :-

  inc CurrentScreen
  lda CurrentScreen
  cmp #16
  bne ScreenLoop

  setCHRBankMacro 0
  rts
.endproc

.proc CallAutotile
  tya ; A = block type ID
  ldy #0 ; Now Y is being used to find the right index

  ; Find the block type in BlockAutotile
: cmp BlockAutotile,y
  beq Found
  iny
  bpl :- ; Unconditional
  rts ; For safety? assert(0)

Found:
  tya
  asl
  tay
  lda BlockAutotileRoutine+1,y
  pha
  lda BlockAutotileRoutine+0,y
  pha
  rts
.endproc
