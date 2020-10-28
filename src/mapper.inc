.ifndef MAPPER_INC
.define MAPPER_INC

.global setPRGBank, setCHRBank, bankcall, bankrts
.globalzp lastPRGBank, lastBankMode

.macro setCHRBankMacro value
  lda #$00
  sta $5000 ; Register select
  .ifnblank value
    lda #value
  .endif
  sta $8000 ; Register value
.endmacro

.endif
