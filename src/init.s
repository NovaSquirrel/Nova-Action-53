.include "nes.inc"
.include "mmc1.inc"
.include "global.inc"

.segment "CODE"
.proc reset_handler
  ; The very first thing to do when powering on is to put all sources
  ; of interrupts into a known state.
  sei             ; Disable interrupts
  ldx #$00
  stx PPUCTRL     ; Disable NMI and set VRAM increment to 32
  stx PPUMASK     ; Disable rendering
  stx $4010       ; Disable DMC IRQ
  dex             ; Subtracting 1 from $00 gives $FF, which is a
  txs             ; quick way to set the stack pointer to $01FF
  bit PPUSTATUS   ; Acknowledge stray vblank NMI across reset
  bit SNDCHN      ; Acknowledge DMC IRQ
  lda #$40
  sta P2          ; Disable APU Frame IRQ
  lda #$0F
  sta SNDCHN      ; Disable DMC playback, initialize other channels

vwait1:
  bit PPUSTATUS   ; It takes one full frame for the PPU to become
  bpl vwait1      ; stable.  Wait for the first frame's vblank.

  ; We have about 29700 cycles to burn until the second frame's
  ; vblank.  Use this time to get most of the rest of the chipset
  ; into a known state.

  cld

  ; Clear stuff
  ldx #0
  jsr ppu_clear_oam  ; clear out OAM from X to end and set X to 0

  txa
clear_zp:
  sta $000,x
  sta $300,x
  sta $400,x
  sta $500,x
  sta $600,x
  sta $700,x
  inx
  bne clear_zp

  sta $4444

  ; Initialize the mapper
  lda #$80   ; Mode
  sta $5000

  lda #%011110 ; Vertical mirroring, UNROM style, 64KB 
  sta $8000

  lda #$81   ; Outer bank supplies bits for the fixed bank
  sta $5000
  lda #1
  sta $8000

vwait2:
  bit PPUSTATUS  ; After the second vblank, we know the PPU has
  bpl vwait2     ; fully stabilized.

  lda #<.bank(main)
  jsr setPRGBank
  jmp main
.endproc

