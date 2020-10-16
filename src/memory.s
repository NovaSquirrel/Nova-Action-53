.include "global.inc"

.segment "ZEROPAGE"
  retraces: .res 1
  keydown: .res 1
  keylast: .res 1
  keynew: .res 1
  seed: .res 4
  ScrollX: .res 2

  ObjectLen = 16
  ObjectF1:         .res ObjectLen ; TTTTTTTD, Type, Direction
  EnemyRightEdge:   .res 1     ; Usually $f0 but can be $70 for 8 pixel wide enemies

  ; player state stuff
  PlayerPXL:        .res 1 ; \ player X and Y positions
  PlayerPXH:        .res 1 ;  \
  PlayerPYH:        .res 1 ;  /
  PlayerPYL:        .res 1 ; /
  PlayerVXH:        .res 1 ; \ player X and Y speeds
  PlayerVXL:        .res 1 ;  \
  PlayerVYH:        .res 1 ;  /
  PlayerVYL:        .res 1 ; /

  PlayerWasRunning: .res 1     ; was the player running when they jumped?
  PlayerDir:        .res 1     ; currently facing left?
  PlayerDirForScroll: .res 1   ; similar but for scrolling purposes
  PlayerJumping:    .res 1     ; true if jumping (not falling)
  PlayerOnGround:   .res 1     ; true if on ground
  PlayerJumpCancelLock: .res 1 ; timer for the player being unable to cancel a jump
  PlayerWalkLock:   .res 1     ; timer for the player being unable to move left/right
  PlayerDownTimer:  .res 1     ; timer for how long the player has been holding down
                               ; (used for fallthrough platforms)
  PlayerSelectTimer:  .res 1   ; timer for how long the player has been holding select
  PlayerHealth:     .res 1     ; current health, measured in half hearts
  PlayerTailAttack: .res 1     ; timer for tail attack animation
  PlayerAnimationFrame: .res 1 ; base frame of the player's animations to use
  PlayerTiles:      .res 7     ; tiles to use while drawing the player
  SoundDebounce:    .res 1     ; timer, while nonzero no new sounds effects start
  ForceControllerBits:  .res 1
  ForceControllerTime:  .res 1

  ScrollUpdateChunk:  .res 1   ; current 32 pixel chunk we're updating

  ; the NES CPU can't access VRAM outside of vblank, so this is a queue
  ; of metatile and byte updates that wait until vblank to trigger
  MaxNumBlockUpdates = 4
  MaxNumTileUpdates  = 4
  BlockUpdateA1:   .res MaxNumBlockUpdates ; \ address of the top two tiles
  BlockUpdateA2:   .res MaxNumBlockUpdates ; /
  BlockUpdateB1:   .res MaxNumBlockUpdates ; \ address of the bottom two tiles
  BlockUpdateB2:   .res MaxNumBlockUpdates ; /
  BlockUpdateT1:   .res MaxNumBlockUpdates ; \ top two tiles to write
  BlockUpdateT2:   .res MaxNumBlockUpdates ;  \
  BlockUpdateT3:   .res MaxNumBlockUpdates ;  / bottom two tiles to write
  BlockUpdateT4:   .res MaxNumBlockUpdates ; /

  TileUpdateA1:    .res MaxNumTileUpdates ; \ address
  TileUpdateA2:    .res MaxNumTileUpdates ; /
  TileUpdateT:     .res MaxNumTileUpdates ; new byte

  ; Scrolling makes use of a buffer that holds 30 tiles that are then written vertically
  ThirtyUpdateAddr: .res 2      ; PPU address to write the buffer to
  ThirtyUpdateTile: .res 30     ; 30 tiles to write

  TempSpace = ThirtyUpdateTile  ; The buffer is also used by non-gameplay stuff, so give it another name
  ScrollLevelPointer: .res 2    ; Pointer to level data, used while scrolling in new tiles

  ; variables for decoding objects during level decompression
  DecodeObjectType   = TempSpace+0 ; object type ID
  DecodeObjectXY     = TempSpace+1 ; X and Y position of the block
  DecodeObjectBlock  = TempSpace+2 ; block ID to rectangle fill with
  DecodeObjectWidth  = TempSpace+3 ; width to rectangle fill with
  DecodeObjectHeight = TempSpace+4 ; height to rectangle fill with

  OamPtr:      .res 1 ; Index the next OAM entry goes in

  ; temporary spots for saving something and then loading it afterwards
  TempVal:     .res 4
  TempX:       .res 1 ; for saving the X register
  TempY:       .res 1 ; for saving the Y register
  TempXSwitch: .res 1 ; SetPRG needs X on UNROM and MMC3, so provide a place to save it
                      ; also general temporary variable for routines that don't switch

  NeedLevelReload:       .res 1 ; If set, decode LevelNumber again

  BlockMiddle: .res 1 ; what block the middle of the player is overlapping

  ; Parameters for the collision routine. ChkTouchGeneric uses screen pixels.
  ; Usable as 10 free RAM bytes.
  TouchTemp:       .res 1
  TouchTemp2:      .res 1
  TouchTopA:       .res 1
  TouchTopB:       .res 1
  TouchLeftA:      .res 1
  TouchLeftB:      .res 1
  TouchWidthA:     .res 1
  TouchWidthB:     .res 1
  TouchHeightA:    .res 1
  TouchHeightB:    .res 1
.ifdef REAL_COLLISION_TEST ; high bytes
  TouchWidthA2:    .res 1
  TouchWidthB2:    .res 1
  TouchHeightA2:   .res 1
  TouchHeightB2:   .res 1
.endif

  SpriteTileSlots:    .res 4   ; \ keep together
  LevelDecodePointer: .res 2   ;  \ in this order
  LevelSpritePointer: .res 2   ;  /
  LevelBackgroundColor: .res 1 ; /
  ; LevelDecodePointer and LevelSpritePointer aren't used elsewhere and can be reused.
  ; The reason they're not already in one of the temporary space buffers is that they're
  ; written as a group, and LevelBackgroundColor and SpriteTileSlots *are* used elsewhere

  LevelHeaderPointer = TouchTemp ; pointer to the level header, for reading it
  LevelDecodeXPos = TouchTemp+2  ; current X position

.segment "BSS"
  PlayerLastGoodX: .res 2
  PlayerLastGoodY: .res 2

  NeedAbilityChange: .res 1
  NeedAbilityChangeNoSound: .res 1
  NeedLevelRerender: .res 1
  JustTeleported:    .res 1 ; if 0, don't redo sprites

  PRGBank:         .res 1  ; current program bank

  ; queue for attribute table updates for scrolling
  AttributeWriteA1: .res 1 ; high address, always the same for the four writes
  AttributeWriteA2: .res 4 ; low address; only four are used because I use the increment by 32 mode
  AttributeWriteD:  .res 8 ; data to write in the eight attributes

  ; continued from the other ones in zeropage
  BlockUpdateL1:   .res MaxNumBlockUpdates ; \ address of the level buffer
  BlockUpdateL2:   .res MaxNumBlockUpdates ; /
  BlockUpdateLV:   .res MaxNumBlockUpdates ; Value to write to the mirror

  ; PlayerLocationLast/Now contain the low byte of the player's position in the level
  ; and are for detecting when entering a new block
  PlayerLocationLast: .res 1
  PlayerLocationNow:  .res 1

  ; Set to 1 if a collectible was touched by something other than the player
  CollectedByProjectile: .res 1
  PlayerLeftRightLock:   .res 1

  ; DelayedMetaEdits set a timer for when a block in the level should be replaced with something else
  MaxDelayedMetaEdits = 10
; DelayedMetaEditIndexHi
  DelayedMetaEditIndexLo: .res MaxDelayedMetaEdits  ; low address in the level array
  DelayedMetaEditTime:    .res MaxDelayedMetaEdits  ; amount of time
  DelayedMetaEditType:    .res MaxDelayedMetaEdits  ; new block type

  ObjectPXH:   .res ObjectLen ; \ horizontal and vertical positions
  ObjectPXL:   .res ObjectLen ;  \
  ObjectPYH:   .res ObjectLen ;  /
  ObjectPYL:   .res ObjectLen ; /
  ObjectVXH:   .res ObjectLen ; \ horizontal and vertical speeds
  ObjectVXL:   .res ObjectLen ;  \
  ObjectVYH:   .res ObjectLen ;  /
  ObjectVYL:   .res ObjectLen ; /
; ObjectF1
  ObjectF2:    .res ObjectLen ; 1SSSSSSS, State
                              ; 0------- free to use
  ObjectF3:    .res ObjectLen ; -------- ;\ free to use. initialized with object variant
  ObjectF4:    .res ObjectLen ; -------- ;/
  ObjectIndexInLevel: .res ObjectLen ; object's index in level list, prevents object from being respawned until it's despawned
  ObjectTimer: .res ObjectLen ; when timer reaches 0, reset state

  ; Physics variables that are translated from the saved options
  NovaAccelSpeed: .res 1
  NovaDecelSpeed: .res 1
  NovaRunSpeedL:  .res 1
  NovaRunSpeedR:  .res 1
  TapRunTimer: .res 1           ; timer for determining if it's a double tap
  TapRunKey:   .res 1           ; which d-pad button the run was started right (left/right)

LevelZeroWhenLoad_Start:
  RunStartedWithTap:      .res 1 ; if 1, the current run started with a tap
  PlayerHasBalloon:       .res 1
  DelayedMetaEditIndexHi: .res MaxDelayedMetaEdits  ; high address in the level array, or 0 if unused
  IsScrollUpdate:         .res 1   ; nonzero = yes
  PlayerOnLadder:         .res 1   ; true if player is on a ladder
  NeedSFX:                .res 1
  PlayerInvincible:       .res 1   ; player invincibility timer, for when getting hurt or otherwise
  PreserveLevel:          .res 1   ; don't reset level when player dies

  ; LevelLinkUp/Down are offsets for what screen to move to if you go off the top or bottom
  LevelLinkUp:            .res 16
  LevelLinkDown:          .res 16
  ScreenFlags:            .res 16
  ScreenFlagsDummy:       .res 1
  ; ScreenFlags stores flags for each screen in the level; so far there's just one flag:
  SCREEN_BOUNDARY = 1 ; boundary on left side of screen
  ; Now more stuff...
  FallingBlockPointer:    .res 2
  FallingBlockY:          .res 1
  CarryingPickupBlock:    .res 1
.ifdef NEW_TOGGLE_BEHAVIOR
  ToggleBlockEnabled:     .res 1 ; 64 if enabled, 0 if not
  ToggleBlockUpload:      .res 1 ; 1 or 2 if it needs uploading
.endif
LevelZeroWhenLoad_End:

  PlayerAbility:      .res 1     ; current ability, see the AbilityType enum

; Current game state (saved in checkpoints)
CurrentGameState:
  Coins:              .res 2     ; 2 digits, BCD
  InventoryLen = 10
  InventoryLenFull = 20          ; full inventory including second page
  InventoryType:           .res InventoryLen
  InventoryPerLevelType:   .res InventoryLen
  InventoryAmount:         .res InventoryLen
  InventoryPerLevelAmount: .res InventoryLen
  InventoryEnd:
GameStateLen = 2+10*4 ; update if more stuff is added. Just coins and inventory.
  InventoryPage: .res 1 ; 0 normally, InventoryLen if second page

  PlayerAbilityVar: .res 1  ; used to keep track of ability-related things
  PlayerNeedsGround: .res 1 ; sets to zero when the player touches the ground
  PlayerRidingSomethingLast: .res 1 ; player was riding something last frame

; Checkpoint information
  CheckpointGameState:   .res GameStateLen
  CheckpointLevelNumber: .res 1
  CheckpointX:           .res 1
  CheckpointY:           .res 1
  MakeCheckpoint:        .res 1

  LevelMusic:         .res 1  ; music number for levels
  PlayerJumpCancel: .res 1
  PlayerSwimming:   .res 1


