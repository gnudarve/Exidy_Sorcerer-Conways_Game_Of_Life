; ================================================================
;
; Conway's Game of Life for the Exidy Sorcerer 
;
; MIT License
;
; Copyright (c) 2026 Walter McGibbony
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
;
; ================================================================

    .format  "PRG"
    .setting "OutputSaveIndividualSegments", false


;Exidy screen is 64x30 but I want a 1 row margin at top and bottom
WIDTH               .equ 64             ; Horizontal wrapping is done with just add/subtract, no border
HEIGHT              .equ 30 - 2         ; We have a top and bottom margin so subtract 2

GENSBEFORERNDRESET  .equ 1333   ;Num gens before we start random reset check, must be less than 65536
RNDRESETTHRESH      .equ 1      ;Threshold for 0-255 random number to trigger reset

    .segment "CODE"
    .org $0000

                PUSH    IY                  ;Preserve IY for Exidy Monitor integrity (9)it crashes if we don't)
                CALL    CLEAR_SCREEN

initBoard:
                LD      HL, board1
                LD      B, HEIGHT
initBoardRow:
                PUSH    BC                  ; Save height for later
                LD      B, WIDTH
initBoardCell:
                CALL    RandLFSR
                CP      256 / 4             ; 25% Chance cell is alive
                LD      (HL), 0
                JP      NC, cellDead
                LD      (HL), 1             ; cell alive
cellDead:       INC     HL
                DJNZ    initBoardCell       ; Complete the row
                POP     BC                  ; Retrieve row counter
                DJNZ    initBoardRow        ; Complete the board

                LD      HL, 0               ; Clear Generation counter
                LD      (nGeneration), HL


mainLoop:
                LD      HL, board1          ; Print board1
                CALL    printBoard

                CALL    MONITOR_QUICKCK     ; Check For Break Char
				JR		Z, mainLoop_cont1   ;  no key
                CP      $1B                 ;  RUN/STOP?
                JR      Z, initBoard
                CP      $03                 ; CTRL-C?
                JR      Z, exit_program                   

mainLoop_cont1:
                LD      IX, board1          ; Board 1 is the old board  
                LD      HL, board2          ; Board 2 is the new board
                CALL    evolve              ; evolve into board 2

                ;Random restart processing, if gens < GENSBEFORERNDRESET no random
                LD      DE, GENSBEFORERNDRESET  ;HL has current gen after evolve
                OR      A                   ; clear carry
                SBC     HL, DE              ; compare HL vs DE
                JP      C, mainLoop_cont1a  ; HL < GENSBEFORERNDRESET → jump
                CALL    RandLFSR            ; Random (but rare) reset
                CP      RNDRESETTHRESH
                JP      C, initBoard
mainLoop_cont1a:
                LD      HL, board2          ;Print board2
                CALL    printBoard

                CALL    MONITOR_QUICKCK     ; Check For Break Char
				JR		Z, mainLoop_cont2   ;  no key
                CP      $1B                 ;  RUN/STOP?
                JR      Z, initBoard
                CP      $03                 ;  CTRL-C?
                JR      Z, exit_program

mainLoop_cont2:
                LD      IX, board2          ; Board 2 is the old board
                LD      HL, board1          ; Board 1 is the new board, point to second row
                CALL    evolve              ; evolve into board 1

                ;Random restart processing, if gens < GENSBEFORERNDRESET no random
                LD      DE, GENSBEFORERNDRESET  ;HL has current gen after evolve
                OR      A                   ; clear carry
                SBC     HL, DE              ; compare HL vs DE
                JP      C, mainLoop_cont2a  ; HL < GENSBEFORERNDRESET → jump
                CALL    RandLFSR            ; Random (but rare) reset
                CP      RNDRESETTHRESH
                JP      C, initBoard

mainLoop_cont2a:
                JP      mainLoop

exit_program:
                POP    IY
                RET


;***** Routines *****



;Evolve
; IX = src board
; HL = dest board
evolve:
                ;CALL    DoReflections          ;Finishes with IX on second row

;-------------------------------------------------------------------------------
; Special first row uses calcCell_Top,calcCell_Top_Left,calcCell_Top_Right

                ; Store a copy of first row location to be used later when we eval the bottom row
                PUSH    IX 

                ; Let IY = bottom row
                PUSH    IX
                POP     IY
                LD      DE, WIDTH * (HEIGHT - 1)   ; get us to bottom row
                ADD     IY, DE

                CALL    calcCell_Top_Left      ;Calculate a left column cell (does l/r reflection)
                INC     HL
                INC     IX
                INC     IY

                LD      B, WIDTH - 2           ;Inner part only
evolveCell_Top:
                CALL    calcCell_Top           ;Calculate an inner cell
                INC     HL
                INC     IX
                INC     IY
                DJNZ    evolveCell_Top         ;Complete inner cells

                CALL    calcCell_Top_Right     ;Calculate a right column cell (does r/l reflection)
                INC     HL
                INC     IX
                ;INC     IY

;-------------------------------------------------------------------------------
; Normal rows

                LD      B,  HEIGHT - 2         ; remove top and botom rows since we roll those out above and below
evolveRow:
                PUSH    BC                     ;Save current height for later   

                CALL    calcCell_Left          ;Calculate a left column cell (does l/r reflection)
                INC     HL
                INC     IX

                LD      B, WIDTH - 2           ;Inner part only
evolveCell:
                CALL    calcCell               ;Calculate an inner cell
                INC     HL
                INC     IX
                DJNZ    evolveCell             ;Complete inner cells

                CALL    calcCell_Right         ;Calculate a right column cell (does r/l reflection)
                INC     HL
                INC     IX

                POP     BC                     ;Retrieve height
                DJNZ    evolveRow              ;Complete the board

;-------------------------------------------------------------------------------
; Special last row

                ; Let IY = top row
                POP     IY      ; we pushed that at the beginning of the routine

                CALL    calcCell_Bottom_Left   ;Calculate a left column cell (does l/r reflection)
                INC     HL
                INC     IX
                INC     IY

                LD      B, WIDTH - 2           ;Inner part only
evolveCell_Bottom:
                CALL    calcCell_Bottom        ;Calculate an inner cell
                INC     HL
                INC     IX
                INC     IY
                DJNZ    evolveCell_Bottom      ;Complete inner cells

                CALL    calcCell_Bottom_Right  ;Calculate a right column cell (does r/l reflection)

                ;INC     HL
                ;INC     IX
                ;INC     IY


                ;Increment generation
                LD      HL, (nGeneration)      
                INC     HL
                LD      (nGeneration), HL

                RET


; Board
; R 2 3  IY
; R x 5
; R 7 8
calcCell_Top_Left:
                XOR     A
                ADD     A, (IY + (WIDTH - 1))           ;Pos 1
                ADD     A, (IY + 0)                     ;Pos 2
                ADD     A, (IY + 1)                     ;Pos 3
                ADD     A, (IX + (WIDTH - 1))           ;Pos 4
                ADD     A, (IX + 1)                     ;Pos 5
                ADD     A, (IX + (WIDTH + WIDTH - 1))   ;Pos 6
                ADD     A, (IX +  WIDTH)                ;Pos 7
                ADD     A, (IX + (WIDTH + 1 ))          ;Pos 8
                JP      evalCell

; Board
; 1 2 L  IY
; 4 x L
; 6 7 L
calcCell_Top_Right:
                XOR     A
                ADD     A, (IY - 1)                     ;Pos 1
                ADD     A, (IY + 0)                     ;Pos 2
                ADD     A, (IY - (WIDTH - 1))           ;Pos 3
                ADD     A, (IX - 1)                     ;Pos 4
                ADD     A, (IX - (WIDTH - 1))           ;Pos 5
                ADD     A, (IX + (WIDTH - 1))           ;Pos 6
                ADD     A, (IX +  WIDTH)                ;Pos 7
                ADD     A, (IX + 1)                     ;Pos 8
                JP      evalCell

; Board
; 1 2 3  IY
; 4 x 5
; 6 7 8  
calcCell_Top:       
                XOR     A
                ADD     A, (IY - 1)                     ;Pos 1
                ADD     A, (IY + 0)                     ;Pos 2
                ADD     A, (IY + 1)                     ;Pos 3
                ADD     A, (IX - 1)                     ;Pos 4
                ADD     A, (IX + 1)                     ;Pos 5
                ADD     A, (IX + (WIDTH - 1))           ;Pos 6
                ADD     A, (IX +  WIDTH)                ;Pos 7
                ADD     A, (IX + (WIDTH + 1))           ;Pos 8
                JP      evalCell

;-------------------------------------------------------------------------------

; Board
; R 2 3
; R x 5
; R 7 8  IY  
calcCell_Bottom_Left:
                XOR     A
                ADD     A, (IX - 1)                     ;Pos 1
                ADD     A, (IX -  WIDTH)                ;Pos 2
                ADD     A, (IX - (WIDTH - 1))           ;Pos 3
                ADD     A, (IX + (WIDTH - 1))           ;Pos 4
                ADD     A, (IX + 1)                     ;Pos 5
                ADD     A, (IY + (WIDTH - 1))           ;Pos 6
                ADD     A, (IY + 0)                     ;Pos 7
                ADD     A, (IY + 1)                     ;Pos 8
                JP      evalCell

; Board
; 1 2 L
; 4 x L
; 6 7 L  IY
calcCell_Bottom_Right:
                XOR     A
                ADD     A, (IX - (WIDTH + 1))           ;Pos 1
                ADD     A, (IX -  WIDTH)                ;Pos 2
                ADD     A, (IX - (WIDTH - 1))           ;Pos 3
                ADD     A, (IX - 1)                     ;Pos 4
                ADD     A, (IX - (WIDTH - 1))           ;Pos 5
                ADD     A, (IY - 1)                     ;Pos 6
                ADD     A, (IY + 0)                     ;Pos 7
                ADD     A, (IY - (WIDTH - 1))           ;Pos 8
                JP      evalCell

; Board
; 1 2 3
; 4 x 5
; 6 7 8  IY
calcCell_Bottom:       
                XOR     A
                ADD     A, (IX - (WIDTH + 1))           ;Pos 1
                ADD     A, (IX -  WIDTH)                ;Pos 2
                ADD     A, (IX - (WIDTH - 1))           ;Pos 3
                ADD     A, (IX - 1)                     ;Pos 4
                ADD     A, (IX + 1)                     ;Pos 5
                ADD     A, (IY - 1)                     ;Pos 6
                ADD     A, (IY + 0)                     ;Pos 7
                ADD     A, (IY + 1)                     ;Pos 8
                JP      evalCell

;-------------------------------------------------------------------------------

; Board
; R 2 3
; R x 5
; R 7 8
calcCell_Left:
                XOR     A
                ADD     A, (IX - 1)                     ;Pos 1
                ADD     A, (IX -  WIDTH)                ;Pos 2
                ADD     A, (IX - (WIDTH - 1))           ;Pos 3
                ADD     A, (IX + (WIDTH - 1))           ;Pos 4
                ADD     A, (IX + 1)                     ;Pos 5
                ADD     A, (IX + (WIDTH - 1))           ;Pos 6
                ADD     A, (IX + WIDTH)                 ;Pos 7
                ADD     A, (IX + (WIDTH + 1 ))          ;Pos 8
                JP      evalCell

; Board
; 1 2 L
; 4 x L
; 6 7 L
calcCell_Right:
                XOR     A
                ADD     A, (IX - (WIDTH + 1))           ;Pos 1
                ADD     A, (IX -  WIDTH)                ;Pos 2
                ADD     A, (IX - (WIDTH - 1))           ;Pos 3
                ADD     A, (IX - 1)                     ;Pos 4
                ADD     A, (IX - (WIDTH - 1))           ;Pos 5
                ADD     A, (IX + (WIDTH - 1))           ;Pos 6
                ADD     A, (IX +  WIDTH)                ;Pos 7
                ADD     A, (IX + 1)                     ;Pos 8
                JP      evalCell

; Board
; 1 2 3   
; 4 x 5
; 6 7 8
calcCell:       
                XOR     A
                ADD     A, (IX - (WIDTH + 1))           ;Pos 1
                ADD     A, (IX -  WIDTH)                ;Pos 2
                ADD     A, (IX - (WIDTH - 1))           ;Pos 3
                ADD     A, (IX - 1)                     ;Pos 4
                ADD     A, (IX + 1)                     ;Pos 5
                ADD     A, (IX + (WIDTH - 1))           ;Pos 6
                ADD     A, (IX +  WIDTH)                ;Pos 7
                ADD     A, (IX + (WIDTH + 1))           ;Pos 8


evalCell:
                CP      3                       
                JR      Z, birth                ; Exactly 3, then birth
                JR      NC, death               ; More than 3, death by overpopulation
                CP      2
                JR      Z, maintain             ; Copies from the last generation
                                                ; Anything else, (0 or 1) dies from loneliness
death:
                LD      (HL), 0
                RET
maintain:
                LD      A, (IX + 0)             ; Self
                LD      (HL), A
                RET
birth:
                LD      (HL), 1
                RET


; printBoard
;
;  HL=board
;
printBoard:
                ;Set screen origin skipping first row, we have upper1 row  and lower margins
                LD      DE, SCREEN_BASE + WIDTH 
                LD      B, HEIGHT           ;Board height without reflection borders
printRow:
                PUSH    BC                  ;Save height for later   
                LD      B, WIDTH
printCell:
                LD      A, (HL)
                AND     A                   ;Test for 0
                JR      Z, printDead
printAlive:                
                LD      A, 132              ;Live cell char
                JP      printCont     
printDead:     
                LD      A, ' '              ;Dead cell char
printCont:
                LD      (DE), A             ;Write to screen

                INC     DE                  ;Next screen addr
                INC     HL                  ;Next cell
                DJNZ    printCell           ;Complete the row

                POP     BC                  ;Retrieve height
                DJNZ    printRow            ;Complete the board

                RET

printBlankRow:
                LD      B, WIDTH
                LD      A, ' '
printBlankRowLoop:
                LD      (DE), A
                INC     DE                  ;Next screen addr
                INC     HL                  ;Next cell
                DJNZ    printBlankRowLoop
                RET


CLEAR_SCREEN:
                LD      HL, SCREEN_BASE
                LD      DE, SCREEN_BASE + 1
                LD      BC, (64 * 30) - 1
                LD      (HL), ' '
                LDIR
                RET
          
                
; RandLFSR
;
; LFSRSeed  needs 8 bytes
;
RandLFSR:
                PUSH    HL
                ;PUSH    DE
                PUSH    BC

                ld hl,LFSRSeed+4
                ld e,(hl)
                inc hl
                ld d,(hl)
                inc hl
                ld c,(hl)
                inc hl
                ld a,(hl)
                ld b,a
                rl e 
                rl d
                rl c 
                rla
                rl e 
                rl d
                rl c 
                rla
                rl e 
                rl d
                rl c 
                rla
                ld h,a
                rl e 
                rl d
                rl c 
                rla
                xor b
                rl e 
                rl d
                xor h
                xor c
                xor d
                ld hl,LFSRSeed+6
                ld de,LFSRSeed+7
                ld bc,7
                lddr
                ld (de),a

                POP     BC
                ;POP     DE
                POP     HL
                ret

    .segment "DATA"

LFSRSeed:       .byte       $2B,$C3,$84,$C2,$8D,$5D,$B1,$85
nGeneration     .word       0
board1:         .storage    WIDTH * HEIGHT
board2:         .storage    WIDTH * HEIGHT

;Top of Exidy screen RAM 
SCREEN_BASE         .equ $F080

; Monitor Entry Points
MONITOR_QUICKCK     .equ $E015
MONITOR_KEYBRD      .equ $E018
MONITOR_VIDEO       .equ $E01B
MONITOR_SENDLINE    .equ $E1BA
MONITOR_CRLF        .equ $E205
MONITOR_HEXOUT_DE   .equ $E1E8
MONITOR_HEXOUT_A    .equ $E1ED
MONITOR_SENDBLANKS  .equ $E2D2

.end
