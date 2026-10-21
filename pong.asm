; Draw Paddle
LDA #$01 ; white

STA $03e3
STA $0403
STA $0423

; Draw score 0
STA $0267  ; horizontal top
STA $0268
STA $0269
STA $0289  ; vertical right
STA $02a9
STA $02c9
STA $02e9
STA $02e8  ; horizontal bottom
STA $02e7
STA $02c7  ; vertical left
STA $02a7
STA $0287

; Draw right wall
STA $021e
STA $023e
STA $025e
STA $027e
STA $029e
STA $02be
STA $02de
STA $02fe
STA $031e
STA $033e
STA $035e
STA $037e
STA $039e
STA $03be
STA $03de
STA $03fe
STA $041e
STA $043e
STA $045e
STA $047e
STA $049e
STA $04be
STA $04de
STA $04fe
STA $051e
STA $053e
STA $055e
STA $057e
STA $059e
STA $05be
STA $05de
STA $05fe

; Paddle address: $03e3
; $00 holds the low byte; $01 holds the high byte
LDA #$e3
STA $00
LDA #$03
STA $01

; Start stopped, with no pending keypress
LDA #$00
STA $02           ; Direction: 0 = stop, 1 = up, 2 = down
STA $ff

; Ball starts at column 16, row 16
LDA #$10
STA $03
STA $05

; Start moving right and down
LDA #$00
STA $04
STA $06

; Draw the initial ball
LDA #$01
JSR paintBall

readInput:
  LDA $ff         ; Capture the last keypress
  LDX #$00
  STX $ff         ; Clear it without changing A

  CMP #$77        ; w
  BEQ setUp
  CMP #$73        ; s
  BEQ setDown
  ; CMP #$20        ; Space
  ; BEQ setStopped
  JMP updatePaddle

setUp:
  LDA #$01
  STA $02
  JMP updatePaddle

setDown:
  LDA #$02
  STA $02
  JMP updatePaddle

; setStopped:
;   LDA #$00
;   STA $02

updatePaddle:
  LDA $02
  CMP #$01
  BEQ moveUp
  CMP #$02
  BEQ moveDown
  JMP inputHandled

moveUp:
  ; Stop at the top: pointer = $0203
  LDA $01
  CMP #$02
  BNE upAllowed
  LDA $00
  CMP #$03
  BEQ inputHandled

upAllowed:
  LDA #$00          ; Black: erase current paddle
  JSR drawPaddle

  ; Subtract $0020 from the pointer
  SEC
  LDA $00
  SBC #$20
  STA $00
  LDA $01
  SBC #$00          ; Include borrow from low byte
  STA $01

  JMP redrawPaddle

moveDown:
  ; Stop at the bottom: top pixel = $05a3
  ; The other pixels will be $05c3 and $05e3
  LDA $01
  CMP #$05
  BNE downAllowed
  LDA $00
  CMP #$a3
  BEQ inputHandled

downAllowed:
  LDA #$00          ; Black: erase current paddle
  JSR drawPaddle

  ; Add $0020 to the pointer
  CLC
  LDA $00
  ADC #$20
  STA $00
  LDA $01
  ADC #$00          ; Include carry from low byte
  STA $01

redrawPaddle:
  LDA #$01          ; White: draw at new position
  JSR drawPaddle

inputHandled:
  JSR updateBall
  ; Small delay before the next movement update
  LDX #$50

frameDelay:
  DEX
  BNE frameDelay

  JMP readInput

; Draw three pixels using the colour already in A
drawPaddle:
  LDY #$00
  STA ($00),Y       ; Top:    pointer + 0
  LDY #$20
  STA ($00),Y       ; Middle: pointer + 32
  LDY #$40
  STA ($00),Y       ; Bottom: pointer + 64
  RTS

updateBall:
  ; Erase the old ball
  LDA #$00
  JSR paintBall

  ; Update vertical position before checking collisions
  JSR moveBallVertical

  LDX $03               ; Ball's column
  LDA $04               ; Horizontal direction
  BEQ ballRight
  JMP ballLeft

ballRight:
  CPX #$1d              ; Right limit: column 29
  BEQ turnLeft
  INX
  JMP drawBall

turnLeft:
  LDA #$01              ; Move left
  STA $04
  DEX
  JMP drawBall

ballLeft:
  CPX #$04              ; Just beside the paddle?
  BEQ checkPaddle
  DEX
  JMP drawBall

checkPaddle:
  ; Convert the paddle pointer into its top row.
  ; First: (high byte - $02) * 8
  LDA $01
  SEC
  SBC #$02
  ASL A
  ASL A
  ASL A
  STA $09               ; Temporary storage

  ; Then add: low byte / 32
  LDA $00
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC $09
  STA $09               ; $09 = paddle's top row

  ; Find ball's row relative to the paddle's top
  LDA $05
  SEC
  SBC $09
  BCC ballMissed        ; Ball is above the paddle

  CMP #$03
  BCS ballMissed        ; Offset >= 3: below the paddle

  ; Offset 0, 1 or 2 means a hit
  JMP turnRight

turnRight:
  LDA #$00              ; Move right
  STA $04
  INX

drawBall:
  STX $03               ; Save new column
  LDA #$01
  JSR paintBall
  RTS

ballMissed:
  LDA #$02              ; Red ball signals a miss
  JSR paintBall

roundOver:
  JMP roundOver         ; Freeze gameplay here

moveBallVertical:
  LDX $05               ; Current row
  LDA $06
  BEQ ballDown
  JMP ballUp

ballDown:
  CPX #$1f              ; Bottom: row 31
  BEQ turnUp
  INX
  JMP saveBallRow

turnUp:
  LDA #$01              ; Direction = up
  STA $06
  DEX
  JMP saveBallRow

ballUp:
  CPX #$08              ; Top of play area: row 8
  BEQ turnDown
  DEX
  JMP saveBallRow

turnDown:
  LDA #$00              ; Direction = down
  STA $06
  INX

saveBallRow:
  STX $05
  RTS


; Draw at the ball's column and row.
; A contains the colour: 0 = black, 1 = white.
paintBall:
  PHA                   ; Save colour while calculating

  ; Low byte of row * 32
  LDA $05
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  CLC
  ADC $03               ; Add column
  STA $07

  ; High byte of screen address
  LDA $05
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$02              ; Screen begins at $0200
  STA $08

  PLA                   ; Restore colour
  LDY #$00
  STA ($07),Y
  RTS