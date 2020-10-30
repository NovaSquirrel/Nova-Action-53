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

.segment "BANK02"

.proc main

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
  
  ; Set up game variables, as if it were the start of a new level.
  jsr init_player

forever:

  ; Game logic
  jsr ReadController
  jsr move_player

  ; The first entry in OAM (indices 0-3) is "sprite 0".  In games
  ; with a scrolling playfield and a still status bar, it's used to
  ; help split the screen.  This demo doesn't use scrolling, but
  ; yours might, so I'm marking the first entry used anyway.  
  ldx #4
  stx OamPtr
  ; adds to OamPtr
  ldx #draw_player_sprite
  jsr bankcall
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
  
  ; Turn the screen on
  ldx #0
  ldy #0
  lda #VBLANK_NMI|BG_0000|OBJ_1000
  sec
  jsr ppu_screen_on
  jmp forever

; And that's all there is to it.
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


