.include "nes.inc"
.include "mapper.inc"
.include "global.inc"
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
.import  BlockPalette, BlockFlags
.import UpdateScrollRegister

.segment "BlockData"

.export RenderLevelScreens
.proc RenderLevelScreens
  lda #0
  sta PPUMASK
  sta IsScrollUpdate

  ; Clear block updates
  ldx #4
: sta TileUpdateA1,x
  sta BlockUpdateA1,x ; overruns a little but it's OK
  dex
  bpl :-
 
  ; Immediately set the correct scroll value
  lda PlayerPXL
  sta ScrollX+0
  lda PlayerPXH
  sub #8
  bcs :+
    lda #0
    sta ScrollX+0
: sta ScrollX+1

  ; Check for scroll locks and adjust for them
  ; Get the screen first
  lda PlayerPXH
  lsr
  lsr
  lsr
  lsr
  tax
  lda PlayerPXH
  and #$0f
  cmp #8
  bcs @OnRight
@OnLeft:
  lda PlayerPXH
  cmp ScrollX+1
  beq @OnSkip
  lda ScreenFlags+0,x
  lsr
  bcc @OnSkip
    lda PlayerPXH
    and #$f0
    sta ScrollX+1
    lda #0
    sta ScrollX+0
  jmp @OnSkip
@OnRight:
  lda ScreenFlags+1,x
  lsr
  bcc @OnSkip
    lda ScrollX+1
    and #$f0
    sta ScrollX+1
    lda #0
    sta ScrollX+0
@OnSkip:

  lda JustTeleported
  beq DidntTeleport
.scope
.if 0
  Low = 14
  High = 15
  ; Object stuff ----
  ; Clear objects
  lda #0
  sta JustTeleported
  ldy #ActorLen-1
: sta ActorType,y
  dey
  bpl :-

  lda CarryingPickupBlock
  beq NoPickupBlock
  jsr FindFreeObjectY
  bcc NoSlotForPickupBlock ; should never fail because objects were just cleared
  lda #Enemy::POOF*2
  sta ObjectF1,y
  lda PlayerPXH
  sta ObjectPXH,y
  lda PlayerPYH
  sta ObjectPYH,y
  lda #PoofSubtype::CARRYABLE_BLOCK
  sta ObjectF2,y
  bne NoPickupBlock
NoSlotForPickupBlock:
  lda #0
  sta CarryingPickupBlock
NoPickupBlock:

  ; Try to spawn enemies
  ; - get low column
  lda ScrollX+1
  sub #4
  bcs :+
    lda #0
  :
  sta Low
  ; - get high column
  lda ScrollX+1
  add #25
  bcc :+
    lda #255
  :
  sta High
  ; Now look through the list
  ldy #0
EnemyLoop:
  lda SpriteListRAM,y
  cmp #255
  beq Exit
  cmp Low
  bcc Nope
  cmp High
  bcs Nope
  jsr TryMakeSprite
Nope:
  iny
  iny
  iny
  bne EnemyLoop
Exit:
.endif
.endscope
DidntTeleport:


  ; Start actually drawing the level
.if 0
  ldx #0
: txa
  sta $600,x
  sta $700,x
  inx
  bne :-
.endif

  ; Load the block cache
  setCHRBankMacro 3
  lda ScrollX+1
  lsr
  sub #4 ; Go back four chunks
  sta 15 ; Current chunk

  ; Loop through the columns we'll write to the 
  lda #15
  sta 14 ; Counter for how many chunks to go
LoadCacheLoop:
  ; Get a level pointer 
  lda 15
  jsr ChunkToCachePointer

  lda #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_1000 ; Increment VRAM address by 1 each time
  sta PPUCTRL

  ; Calculate the starting PPU address
  lda #0
  sta 0
  lda 15
  asl
  ;---
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
  sta PPUADDR
  bit PPUDATA ; Read once to work around the $2007 read delay thing

  ldy #0
: lda PPUDATA
  sta (ScrollLevelPointer),y
  iny
  cpy #32
  bne :-

  inc 15
  dec 14
  bne LoadCacheLoop

  setCHRBankMacro

  ; -------------------------

  ; Start drawing chunks
  lda ScrollX+1
  lsr
  sub #2  ; Go back two chunks
  sta 15  ; Current chunk
  lda #13
  sta 14  ; Counter for how many chunks to go
: lda 15
  jsr RenderLevel32Wide
  inc 15
  dec 14
  bne :-

;  jsr ClearOAM
  jsr UpdateScrollRegister
  jsr WaitVblank
;  lda #2
;  sta OAM_DMA
  lda #BG_ON;|OBJ_ON
  sta PPUMASK
  rts
.endproc

; Saves the pointer in ScrollLevelPointer
.proc ChunkToCachePointer
LPointer = ScrollLevelPointer
  ldx #0
  stx LPointer+1
  and #15
  ora #%00110000 ; Makes sure the resulting pointer is $6xx or $7ff
  .repeat 5
    asl
    rol LPointer+1
  .endrep
  sta LPointer
  rts
.endproc

; Render a 32 pixel wide chunk
; Very similar to the scrolling code
; input: A (level chunk number)
; locals: 2, 3, 4, 5, 6, 7, more
.proc RenderLevel32Wide
LPointer = ScrollLevelPointer
; ThirtyUpdateAddr ; big endian
LevelIndex = 2 ; index for (ScrollLevelPointer),y
AttrIndex = 3
Chunk = 4
Temp = 5
RPointer = 6
  sta Chunk

  lda #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_1000 | VRAM_DOWN ; Increment VRAM address by 32 each time
  sta PPUCTRL

  ; Multiply to get the level pointer
  lda Chunk
  jsr ChunkToCachePointer
  ; A = LPointer+0 still
  ; Make another pointer that's one column to the right
  ora #16
  sta RPointer+0
  lda LPointer+1
  sta RPointer+1

  ; Make the PPU address we'll start with
  lda Chunk ; 32 pixels across, so multiply by 4
  asl
  asl
  and #31
  sta ThirtyUpdateAddr+1
  ; Determine if it's the first or second nametable
  lda Chunk
  and #%1000 ; becomes 0 or 4
  lsr
  ora #$20   ; $20xx or $24xx
  sta ThirtyUpdateAddr+0

; -------------------------------
; START OF ATTRIBUTE TABLE CODE
; -------------------------------
  ldy #0        ; Start at the top of the column
  sty AttrIndex ; and start of the attributes array
LoopAttr:
  ; top left corner of attribute byte
  lda (LPointer),y
  tax
  lda BlockPalette,x
  and #%00000011
  sta Temp
  ; top right corner of attribute byte
  lda (RPointer),y
  tax
  lda BlockPalette,x
  and #%00001100
  ora Temp
  sta Temp
  iny
  ; bottom left corner of attribute byte
  lda (LPointer),y
  tax
  lda BlockPalette,x
  and #%00110000
  ora Temp
  sta Temp
  ; top right corner of attribute byte
  lda (RPointer),y
  tax
  lda BlockPalette,x
  and #%11000000
  ora Temp
  iny

  ; store the attribute byte we just built
  ldx AttrIndex
  sta AttributeWriteD,x
  inx
  stx AttrIndex
  cpx #8
  bne LoopAttr

  ; make attribute addresses
  lda Chunk
  and #7
  sta Temp
  ldx #3
: lda AttributeAddrsLo,x
  ora Temp
  sta AttributeWriteA2,x
  dex
  bpl :-

  ; Make high address for all the attribute writes,
  ; which will be on the same nametable as the tile updates
  lda ThirtyUpdateAddr+0
  ora #3
  sta AttributeWriteA1

  ; Write attributes
  .repeat 4, I
    lda AttributeWriteA1
    sta PPUADDR
    lda AttributeWriteA2+I
    sta PPUADDR
    lda AttributeWriteD+I
    sta PPUDATA
    lda AttributeWriteD+I+4
    sta PPUDATA
  .endrep
; -------------------------------
; END OF ATTRIBUTE TABLE CODE
; -------------------------------

  jsr UpdateScrollBufferLeft
  jsr Write30
  jsr UpdateScrollBufferRight
  jsr Write30
  lda RPointer+0 ; Use the right side
  sta LPointer+0
  jsr UpdateScrollBufferLeft
  jsr Write30
  jsr UpdateScrollBufferRight
  jmp Write30

Write30: ; Write one column of tiles
  ldx #0
  lda ThirtyUpdateAddr+0
  sta PPUADDR
  lda ThirtyUpdateAddr+1
  sta PPUADDR
: lda ThirtyUpdateTile,x
  sta PPUDATA
  inx
  cpx #30
  bne :-
  inc ThirtyUpdateAddr+1 ; Move to the next column
  rts
AttributeAddrsLo:
  .byt $c0, $c8, $d0, $d8
.endproc

.proc UpdateScrollBufferLeft
LevelIndex = 0
  ldy #0
LoopLeft:
  sty LevelIndex
  lda (ScrollLevelPointer),y
  tax
  tya
  asl ; Thirty index is LevelIndex * 2
  tay
  lda BlockTopLeft,x
  sta ThirtyUpdateTile+0,y
  lda BlockBottomLeft,x
  sta ThirtyUpdateTile+1,y
  ldy LevelIndex
  iny
  cpy #15
  bne LoopLeft
  rts
.endproc

.proc UpdateScrollBufferRight
LevelIndex = 0
  ldy #0
LoopRight:
  sty LevelIndex
  lda (ScrollLevelPointer),y
  tax
  tya
  asl ; Thirty index is LevelIndex * 2
  tay
  lda BlockTopRight,x
  sta ThirtyUpdateTile+0,y
  lda BlockBottomRight,x
  sta ThirtyUpdateTile+1,y
  ldy LevelIndex
  iny
  cpy #15
  bne LoopRight
  rts
.endproc
