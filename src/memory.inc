LevelCache = $600
LevelCache2 = $700
ActorLen = 16
MaxDelayedMetaEdits = 10

  .globalzp retraces, keydown, keylast, keynew, seed, ScrollX
  .globalzp ActorType
  .globalzp EnemyRightEdge
  .globalzp PlayerPXL, PlayerPXH, PlayerPYH, PlayerPYH
  .globalzp PlayerVXL, PlayerVXH, PlayerVYH, PlayerVYH
  .globalzp PlayerWasRunning, PlayerDir, PlayerJumping, PlayerOnGround, PlayerJumpCancelLock, PlayerWalkLock, PlayerDownTimer, PlayerSelectTimer
  .globalzp PlayerHealth, PlayerTailAttack, PlayerAnimationFrame, PlayerTiles, SoundDebounce, ForceControllerBits, ForceControllerTime
  .globalzp ScrollUpdateChunk

  ; the NES CPU can't access VRAM outside of vblank, so this is a queue
  ; of metatile and byte updates that wait until vblank to trigger
  MaxNumBlockUpdates = 4
  MaxNumTileUpdates  = 4
  .globalzp BlockUpdateA1, BlockUpdateA2, BlockUpdateB1, BlockUpdateB2
  .globalzp BlockUpdateT1, BlockUpdateT2, BlockUpdateT3, BlockUpdateT4
  .globalzp TileUpdateA1, TileUpdateA2, TileUpdateT

  .globalzp ThirtyUpdateAddr
  .globalzp ThirtyUpdateTile
  TempSpace = ThirtyUpdateTile
  .globalzp ScrollLevelPointer

  ; variables for decoding objects during level decompression
  DecodeObjectType   = TempSpace+0 ; object type ID
  DecodeObjectXY     = TempSpace+1 ; X and Y position of the block
  DecodeObjectBlock  = TempSpace+2 ; block ID to rectangle fill with
  DecodeObjectWidth  = TempSpace+3 ; width to rectangle fill with
  DecodeObjectHeight = TempSpace+4 ; height to rectangle fill with

  .globalzp OamPtr
  .globalzp TempVal, TempX, TempY
  .globalzp NeedLevelReload, LevelNumber
  .globalzp BlockMiddle
  .globalzp TouchTemp, TouchTemp2, TouchTopA, TouchtopB, TouchLeftA, TouchLeftB, TouchWidthA, TouchWidthB, TouchHeightA, TouchHeightB
  .globalzp TouchWidthA2, TouchWidthB2, TouchHeightA2, TouchHeightB2
  .globalzp SpriteTileSlots
  .globalzp LevelDecodePointer
  .globalzp LevelSpritePointer
  .globalzp LevelBackgroundColor

  LevelHeaderPointer = TouchTemp ; pointer to the level header, for reading it
  LevelDecodeXPos = TouchTemp+2  ; current X position

.segment "BSS"
  .global PlayerLastGoodX, PlayerLastGoodY
  .global NeedAbilityChange, NeedAbilityChangeNoSound
  .global NeedLevelRerender
  .global JustTeleported
  .global AttributeWriteA1, AttributeWriteA2, AttributeWriteD
  .global BlockUpdateL1, BlockUpdateL2, BlockUpdateLV
  .global PlayerLocationLast, PlayerLocationNow
  .global CollectedByProjectile, PlayerLeftRightLock 
  .global DelayedMetaEditIndexLo
  .global DelayedMetaEditTime
  .global DelayedMetaEditType
  .global ActorPXH, ActorPXL, ActorPYH, ActorPYL
  .global ActorVXH, ActorVXL, ActorVYH, ActorVYL
  .global ActorState, ActorVarA, ActorVarB, ActorIndexInLevel, ActorTimer
  .global NovaAccelSpeed, NovaDecelSpeed, NovaRunSpeedL, NovaRunSpeedR, TapRunTimer, TapRunKey, SNESController

  .global LevelZeroWhenLoad_Start
  .global RunStartedWithTap
  .global PlayerHasBalloon
  .global DelayedMetaEditIndexHi
  .global IsScrollUpdate, PlayerOnLadder, NeedSFX, PlayerInvincible, PreserveLevel
  .global LevelLinkUp
  .global LevelLinkDown
  .global ScreenFlags
  .global ScreenFlagsDummy
  SCREEN_BOUNDARY = 1 ; boundary on left side of screen

  .global FallingBlockPointer
  .global FallingBlockY
  .global CarryingPickupBlock
  .global LevelZeroWhenLevel_End
  .global PlayerAbility

  .global Coins
  .global PlayerAbilityVar
  .global PlayerNeedsGround, PlayerRidingSomethingLast
  .global CheckpointLevelNumber, CheckpointX, CheckpointY, MakeCheckpoint, LevelMusic, PlayerJumpCancel, PlayerSwimming
