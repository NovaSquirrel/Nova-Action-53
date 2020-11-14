.include "memory.inc"

.ifndef GLOBAL_INC
.define GLOBAL_INC

; init.s
.global reset_handler

; main.s
.global OAM
.global main, nmi_handler, irq_handler
.globalzp cur_keys, new_keys, oam_used
.global WaitVblank

; bg.s
.global draw_bg

; player.s
.global init_player, move_player

; pads.s
.global ReadController

; ppuclear.s
.global ppu_clear_nt, ppu_clear_oam, ppu_screen_on

; bankcall ids
.globalzp draw_player_sprite, load_chr_ram

; global.s
.global GetLevelColumnPtr

.macro RealXPosToScreenPos RealLo, RealHi, Store
  lda RealLo
  sub ScrollX+0
  sta Store

  lda RealHi
  sbc ScrollX+1
  .repeat 4
    lsr
    ror Store
  .endrep
.endmacro

.macro RealYPosToScreenPos RealLo, RealHi, Store
  lda RealLo
  sta Store

  lda RealHi
  .repeat 4
    lsr
    ror Store
  .endrep
.endmacro

.macro RealXPosToScreenPosByX RealLo, RealHi, Store
  lda RealLo,x
  sub ScrollX+0
  sta Store

  lda RealHi,x
  sbc ScrollX+1
  .repeat 4
    lsr
    ror Store
  .endrep
.endmacro

.macro RealYPosToScreenPosByX RealLo, RealHi, Store
  lda RealLo,x
  sta Store

  lda RealHi,x
  .repeat 4
    lsr
    ror Store
  .endrep
.endmacro

.macro RealXPosToScreenPosByY RealLo, RealHi, Store
  lda RealLo,y
  sub ScrollX+0
  sta Store

  lda RealHi,y
  sbc ScrollX+1
  .repeat 4
    lsr
    ror Store
  .endrep
.endmacro

.macro RealYPosToScreenPosByY RealLo, RealHi, Store
  lda RealLo,y
  sta Store

  lda RealHi,y
  .repeat 4
    lsr
    ror Store
  .endrep
.endmacro

.endif
