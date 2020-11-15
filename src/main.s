;
; Simple sprite demo for NES
; Copyright 2011 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

.include "nes.inc"
.include "mapper.inc"
.include "global.inc"

OAM = $0200

.segment "ZEROPAGE"

.segment "CODE"

.export WaitVblank
.proc WaitVblank
  lda retraces
: cmp retraces
  beq :-
  rts
.endproc

.proc nmi_handler
  inc retraces
  rti
.endproc

.proc irq_handler
  rti
.endproc

.code
.proc main
  lda #2
  sta NovaAccelSpeed
  lda #4
  sta NovaDecelSpeed
  lda #<-(4*16)
  sta NovaRunSpeedL
  lda #<(4*16)
  sta NovaRunSpeedR

  ; Now the PPU has stabilized, and we're still in vblank.  Copy the
  ; palette right now because if you load a palette during forced
  ; blank (not vblank), it'll be visible as a rainbow streak.
  jsr load_main_palette

  ; While in forced blank we have full access to VRAM.
  ; Copy CHR data to CHR RAM.
  ldx #load_chr_ram
  jsr bankcall

  ; Then load the nametable (background map).
  jsr draw_bg

  .import RenderLevelScreens
  lda #<.bank(RenderLevelScreens)
  jsr setPRGBank
  jsr RenderLevelScreens  

  ; Set up game variables, as if it were the start of a new level.
;  jsr init_player

forever:

  ; Game logic
  countdown IsScrollUpdate ; decrease scroll update stage
  jsr ReadController

  ldx #0
  stx OamPtr

  .import RunPlayer
  lda #<.bank(RunPlayer)
  jsr setPRGBank
  jsr RunPlayer
  .import AdjustCamera
  jsr AdjustCamera
  .import DisplayPlayer
  jsr DisplayPlayer

;  ldx #draw_player_sprite
;  jsr bankcall
  ldx OamPtr
  jsr ppu_clear_oam

  ; Wait for next screen
  lda retraces
: cmp retraces
  beq :-

  ; Copy the display list from main RAM to the PPU
  lda #0
  sta OAMADDR
  lda #>OAM
  sta OAM_DMA

  ; -------------------------------------------------------
  ; The VRAM is unusable outside of vertical blank because the PPU is constantly using it.
  ; This game writes to queues during gameplay when it wants VRAM changes, and waits for vertical blank
  ; to actually perform the changes.
  bit PPUSTATUS

  ; if IsScrollUpdate is set, update the side of the screen with the ThirtyUpdate buffer
  lda IsScrollUpdate
  jeq NotScrollUpdate
    cmp #3 ; Stage 1 and 2 have to do with updating the level cache
    jcc ReadCacheInVblank

    lda #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_1000 | VRAM_DOWN ; write vertically
    sta PPUCTRL
    lda ThirtyUpdateAddr+0
    sta PPUADDR
    lda ThirtyUpdateAddr+1
    sta PPUADDR
    .repeat 30, I
      lda ThirtyUpdateTile+I
      sta PPUDATA
    .endrep
    ; Update attributes so the newly scrolled-in tiles have the right colors
    ; Note: Vertical writes are still on! This cuts the number of times we need to write
    ; to PPUADDR in half.
    lda IsScrollUpdate
    cmp #6
    bne Not6
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
    Not6:
  NotScrollUpdate:

  ; Horizontal writes again
  lda #VBLANK_NMI | NT_2000 | OBJ_8X8 | BG_0000 | OBJ_1000
  sta PPUCTRL

  .if 0
  ; Upload four tiles worth of data (64 bytes) to a PPU address if needed
  lda UploadTileAddress+1
  beq NoUploadTile
    sta PPUADDR
    lda UploadTileAddress+0
    sta PPUADDR
    jsr UploadFourTiles
  NoUploadTile:
  .endif

  ; Queue for up to four single-byte changes
  .repeat 4, I ; change if the max number of tile changes per frame is changed
    lda TileUpdateA1+I
    beq :+
      sta PPUADDR
      lda TileUpdateA2+I
      sta PPUADDR
      lda TileUpdateT+I
      sta PPUDATA
      lda #0
      sta TileUpdateA1+I
    :
  .endrep

  ; Queue for up to four changes the size of a block
  .repeat 4, I
    lda BlockUpdateA1+I
    beq :+
      sta PPUADDR
      lda BlockUpdateA2+I
      sta PPUADDR
      lda BlockUpdateT1+I
      sta PPUDATA
      lda BlockUpdateT2+I
      sta PPUDATA

      lda BlockUpdateB1+I
      sta PPUADDR
      lda BlockUpdateB2+I
      sta PPUADDR
      lda BlockUpdateT3+I
      sta PPUDATA
      lda BlockUpdateT4+I
      sta PPUDATA
      lda #0
      sta BlockUpdateA1+I
    :
  .endrep

  ; The PPU address register is the same as the scroll register, so
  ; change the scroll value to be correct again
  .import UpdateScrollRegister
  jsr UpdateScrollRegister
  lda #OBJ_ON|BG_ON ; Turn screen on
  sta PPUMASK
  jmp forever
.endproc

.proc ReadCacheInVblank
  lsr ; Don't do anything at stage 1
  jcs main::NotScrollUpdate

  setCHRBankMacro 3 ; Level CHR bank

  ; At stage 2, read from level buffer
  lda ScrollCacheUpdateSource+1
  sta PPUADDR
  lda ScrollCacheUpdateSource+0
  sta PPUADDR
  bit PPUDATA
  .repeat 31, I
    lda PPUDATA
    sta ThirtyUpdateTile+I
  .endrep

  lda #0
  sta $8000 ; Reset to normal CHR bank
Skip:
  jmp main::NotScrollUpdate
.endproc

.proc load_main_palette
  jsr WaitVblank
  ; seek to the start of palette memory ($3F00-$3F1F)
  ldx #$3F
  stx PPUADDR
  ldx #$00
  stx PPUADDR
copypalloop:
  lda initial_palette,x
  sta PPUDATA
  inx
  cpx #32
  bcc copypalloop
  rts
.endproc

AdjustCamera:
  rts

.segment "RODATA"
initial_palette:
  .byt $31, $1a, $2a, $37
  .byt $31, $2d, $3d, $30
  .byt $31, $17, $27, $37
  .byt $31, $05, $15, $25

  .byt $31, $12, $2a, $30
  .byt $31, $2d, $3d, $30
  .byt $31, $06, $16, $26
  .byt $31, $16, $27, $37
;  .byt $22,$18,$28,$38,$0F,$06,$16,$26,$0F,$08,$19,$2A,$0F,$02,$12,$22
;  .byt $22,$08,$16,$37,$0F,$06,$16,$26,$0F,$0A,$1A,$2A,$0F,$02,$12,$22

