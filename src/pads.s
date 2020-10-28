.export ReadController
.importzp keydown, keylast, keynew
.import SNESController
JOY1      = $4016
JOY2      = $4017

.proc ReadController
  lda keydown
  sta keylast

  ; Reset the controller by writing a 1 and then a 0
  lda #1
  sta keydown
  sta JOY1
  lda #0
  sta JOY1

  ; Loop for the first controller byte
: lda JOY1
  and #$03 ; Shift in a bit if either of the two bottom bits
  cmp #1   ; are 1. The Famicom can use either bit.
  rol keydown
  bcc :-

  ; Don't read a second byte if it's NES
  lda SNESController
  beq Finish

SNES:
  lda keydown+1
  sta keylast+1

  lda #1
  sta keydown+1
  ; Loop for the second controller byte
: lda JOY1
  and #$03 ; Shift in a bit if either of the two bottom bits
  cmp #1   ; are 1. The Famicom can use either bit.
  rol keydown+1
  bcc :-

  lda keylast+1
  eor #255
  and keydown+1
  sta keynew+1

Finish:
  ; keynew lists keys that are pressed but weren't pressed last frame
  lda keylast
  eor #255
  and keydown
  sta keynew
  rts
.endproc
