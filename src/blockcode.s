.include "nes.inc"
.include "mapper.inc"
.include "global.inc"
.include "blockenum.s"

.segment "BlockCode"
.import BlockFlags

.export BlockBomb
.proc BlockBomb
  rts
.endproc

.export BlockBricks
.proc BlockBricks
  rts
.endproc

.export BlockCeilingBarrier
.proc BlockCeilingBarrier
  rts
.endproc

.export BlockDoorBottom
.proc BlockDoorBottom
  rts
.endproc

.export BlockHeart
.proc BlockHeart
  rts
.endproc

.export BlockSmallHeart
.proc BlockSmallHeart
  rts
.endproc

.export BlockKey
.proc BlockKey
  rts
.endproc

.export BlockLock
.proc BlockLock
  rts
.endproc

.export BlockMoney
.proc BlockMoney
  rts
.endproc

.export BlockPickupBlock
.proc BlockPickupBlock
  rts
.endproc

.export BlockPushableBlock
.proc BlockPushableBlock
  rts
.endproc

.export BlockPrize
.proc BlockPrize
  rts
.endproc

.export BlockSpike
.proc BlockSpike
  rts
.endproc

.export BlockSpring
.proc BlockSpring
  rts
.endproc

.export BlockWoodArrowRight
.proc BlockWoodArrowRight
  rts
.endproc

.export BlockWoodArrowDown
.proc BlockWoodArrowDown
  rts
.endproc

.export BlockWoodArrowLeft
.proc BlockWoodArrowLeft
  rts
.endproc

.export BlockWoodArrowUp
.proc BlockWoodArrowUp
  rts
.endproc

.export BlockWoodCrate
.proc BlockWoodCrate
  rts
.endproc

;------------------------------------------------------------------------------
ScreenBuffer = LevelCache+16
ScreenBufferLeft = ScreenBuffer-16
ScreenBufferRight = ScreenBuffer+16
; Each of these routines are called with X = the index within ScreenBuffer

.export AutotileTerrain
.proc AutotileTerrain
  ; Put a line below
  lda ScreenBuffer+1,x
  bne :+
    lda #Block::BelowTerrain
    sta ScreenBuffer+1,x
  :

  ; UDLR
  lda #0
  sta 0
  lda ScreenBuffer-1,x
  jsr IsTerrain
  lda ScreenBuffer+1,x
  jsr IsTerrain
  lda ScreenBufferLeft,x
  jsr IsTerrain
  lda ScreenBufferRight,x
  jsr IsTerrain
  ldy 0
  cpy #15
  beq ExtraChecks
  lda TerrainTable,y
  sta ScreenBuffer,x
  rts

ExtraChecks:
  lda #0
  sta 0
  lda ScreenBufferLeft-1,x
  jsr IsTerrain
  lda ScreenBufferRight-1,x
  jsr IsTerrain
  ldy 0
  lda ExtraTable,y
  sta ScreenBuffer,x
  rts

TerrainTable:
  .byt Block::TerrainSingle ; udlr
  .byt Block::TerrainLeft ; udlR
  .byt Block::TerrainRight ; udLr
  .byt Block::Terrain ; udLR

  .byt Block::TerrainSingle ; uDlr
  .byt Block::TerrainLeft ; uDlR
  .byt Block::TerrainRight ; uDLr
  .byt Block::Terrain ; uDLR

  .byt Block::TerrainSingleInside ; Udlr
  .byt Block::TerrainLeftSide ; UdlR
  .byt Block::TerrainRightSide ; UdLr
  .byt Block::TerrainInside ; UdLR

  .byt Block::TerrainSingleInside ; UDlr
  .byt Block::TerrainLeftSide ; UDlR
  .byt Block::TerrainRightSide ; UDLr
;  .byt Block::Terrain ; UDLR

ExtraTable:
  .byt Block::TerrainInside
  .byt Block::TerrainInsideL
  .byt Block::TerrainInsideR
  .byt Block::TerrainInside

IsTerrain:
  cmp #Block::TerrainInsideR+1
  bcs NotTerrain
  cmp #Block::Terrain
  bcc NotTerrain
  rol 0
  rts
NotTerrain:
  clc
  rol 0
  rts
.endproc

.export AutotileLadder
.proc AutotileLadder
  lda ScreenBuffer-1,x
  cmp #Block::Ladder
  beq LadderAbove
  cmp #Block::LadderTop
  beq LadderAbove
  lda #Block::LadderTop
  sta ScreenBuffer,x
LadderAbove:
  rts
.endproc

.export AutotileStone
.proc AutotileStone
  ; UDLR
  lda #0
  sta 0
  lda ScreenBuffer-1,x
  jsr IsStone
  lda ScreenBuffer+1,x
  jsr IsStone
  lda ScreenBufferLeft,x
  jsr IsStone
  lda ScreenBufferRight,x
  jsr IsStone
  lda 0
  add #Block::StoneSingle
  sta ScreenBuffer,x
  rts

IsStone:
  cmp #Block::StoneMiddle+1
  bcs NotStone
  cmp #Block::StoneSingle
  bcc NotStone
  rol 0
  rts
NotStone:
  clc
  rol 0
  rts
.endproc

.export AutotileFloatingPlatform
.proc AutotileFloatingPlatform
  lda #0
  sta 0
  lda ScreenBufferLeft,x
  jsr IsPlatform
  lda ScreenBufferRight,x
  jsr IsPlatform
  lda 0
  add #Block::FloatingPlatform
  sta ScreenBuffer,x
  rts

IsPlatform:
  cmp #Block::FloatingPlatformMiddle+1
  bcs AutotileStone::NotStone
  cmp #Block::FloatingPlatform
  bcc AutotileStone::NotStone
  rol 0
  rts
.endproc

.export AutotileFloatingPlatformFallthrough
.proc AutotileFloatingPlatformFallthrough
  lda #0
  sta 0
  lda ScreenBufferLeft,x
  jsr IsPlatform
  lda ScreenBufferRight,x
  jsr IsPlatform
  lda 0
  add #Block::FloatingPlatformFallthrough
  sta ScreenBuffer,x
  rts

IsPlatform:
  cmp #Block::FloatingPlatformMiddleFallthrough+1
  bcs AutotileStone::NotStone
  cmp #Block::FloatingPlatformFallthrough
  bcc AutotileStone::NotStone
  rol 0
  rts
.endproc

.export AutotileWater
.proc AutotileWater
  ldy ScreenBuffer-1,x
  cpy #Block::WaterMiddle
  beq Water
  cpy #Block::WaterTop
  beq Water
  lda BlockFlags,y
  bpl Nonsolid
Solid:
  lda #Block::WaterBelow
  sta ScreenBuffer,x
  rts
Nonsolid:
  lda #Block::WaterTop
  sta ScreenBuffer,x
  rts
Water:
  rts
.endproc

.export AutotileWhiteFence
.proc AutotileWhiteFence
  rts
.endproc

.export AutotileBrickFence
.proc AutotileBrickFence
  lda ScreenBuffer-1,x
  cmp #Block::BrickFenceTop
  beq BrickFenceAbove
  cmp #Block::BrickFence
  beq BrickFenceAbove
  lda #Block::BrickFenceTop
  sta ScreenBuffer,x
BrickFenceAbove:
  rts
.endproc

.export AutotileSmallBush
.proc AutotileSmallBush
  lda #Block::SmallBushBottom
  sta ScreenBuffer+1,x
  rts
.endproc

.export AutotileTree
.proc AutotileTree
  rts
.endproc

.export AutotileWoodPlatform
.proc AutotileWoodPlatform
  rts
.endproc

.export AutotileJungleBridge
.proc AutotileJungleBridge
  rts
.endproc

.export AutotileDoor
.proc AutotileDoor
  lda #Block::DoorBottom
  sta ScreenBuffer+1,x
  inx
  rts
.endproc

.export AutotileBigBush
.proc AutotileBigBush
  rts
.endproc

.export AutotilePier
.proc AutotilePier
Loop:
  inx
  txa
  and #15
  beq Exit
  lda ScreenBuffer,x
  bne Exit
  lda #Block::PierMiddle
  sta ScreenBuffer,x
  bne Loop ; Unconditional  
Exit:
  dex
  rts
.endproc
