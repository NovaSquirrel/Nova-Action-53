.segment "LevelData"

.include "levelcommandenum.s"

; Define the macros

.macro LSpr Type, Direction, XPos, YPos, Extra
  .byt XPos
  .ifnblank Extra
    .byt (Extra<<4)|YPos
  .else
    .byt YPos
  .endif
  .byt (Type<<1)|Direction
.endmacro

.macro LObj Type, XPos, YPos, Extra1, Extra2
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 15, error, "Invalid Y position"
  .byt Type
  .byt (XPos<<4)|YPos
  .ifnblank Extra1
    .byt Extra1
    .ifnblank Extra2
      .byt Extra2
    .endif
  .endif
.endmacro

.macro LObjN Type, XPos, YPos, Width, Height, Extra
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 15, error, "Invalid Y position"
  .assert Width >= 0 && Width <= 15, error, "Invalid width"
  .assert Height >= 0 && Height <= 15, error, "Invalid height"
  LObj Type, XPos, YPos, (Width<<4)|Height
  .ifnblank Extra
    .byt Extra
  .endif
.endmacro

.macro LFinished
  .byt $f0
.endmacro

.macro LSetX NewX
  .byt $f1, NewX
.endmacro

.macro LWriteCol Col1, Col2, Col3
  .ifnblank Col3
    .byt $f4
    .byt Col1, Col2, Col3
  .else
    .ifnblank Col2
      .byt $f3
      .byt Col1, Col2
    .else
      .byt $f2
      .byt Col1
    .endif
  .endif
.endmacro

.macro LXMinus16
  .byt $f5
.endmacro

.macro LXPlus16
  .byt $f6
.endmacro

LSpecialCmd = $f7

;-----------------------------------------------------------------------------

.importzp FirstSingleType, FirstRectType, FirstWideType, FirstTallType, FirstBigRectType

.macro LSingle type, rx, ry
	LObj FirstSingleType+type, rx, ry
.endmacro

.macro LRect type, rx, ry, rw, rh
	LObjN FirstRectType+type, rx, ry, rw, rh
.endmacro

.macro LWide type, rx, ry, rw
	LObjN FirstWideType+(type/16), rx, ry, rw, type&15
.endmacro

.macro LTall type, rx, ry, rh
	LObjN FirstTallType+(type/16), rx, ry, rh, type&15
.endmacro

.macro LBigRect type, rx, ry, rw, rh
	LObjN FirstBigRectType+(type/16), rx, ry, rh, type&15, rw
.endmacro

;-----------------------------------------------------------------------------

.enum MusicTracks
	NONE
.endenum

.enum GraphicsUpload
	SP_WALKER
	SP_CANNON
	SP_FIRE
	SP_KING
.endenum

.enum Enemy
	GOOMBA
.endenum

;-----------------------------------------------------------------------------
.export LevelPointerList
LevelPointerList:
  .addr testlevel

.include "../levels/testlevel.s"
