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

; Buffered reflections on top and bottom

HEIGHT_WB           .equ 30

WIDTH               .equ 64             ;Horizontal wrapping is done with just add/subtract, no border
HEIGHT              .equ HEIGHT_WB - 2  ;We have a top and bottom reflection border for wrapping the playing board

GENSBEFORERNDRESET  .equ 1333   ;Num gens before we start random reset check, must be less than 65536
RNDRESETTHRESH      .equ 1      ;Threshold for 0-255 random number to trigger reset

    .segment "CODE"
    .org $0000

                PUSH    IY                  ;preserve IY for monitor integrity
                CALL    CLEAR_SCREEN

initBoard:
                LD      HL, board1 + WIDTH
                LD      B, HEIGHT
initBoardRow:
                PUSH    BC                  ;Save height for later
                LD      B, WIDTH
initBoardCell:
                CALL    RandLFSR
                CP      256 / 4             ; 25% Chance cell is alive
                LD      (HL), 0
                JP      NC, cellDead
                LD      (HL), 1             ; cell alive
cellDead:       INC     HL
                DJNZ    initBoardCell       ;Complete the row
                POP     BC                  ;Retrieve row counter
                DJNZ    initBoardRow        ;Complete the board

                LD      HL, 0               ;Clear Generation counter
                LD      (nGeneration), HL


mainLoop:
                LD      HL, board1          ;Print board1
                CALL    printBoard

                CALL    MONITOR_QUICKCK     ;Check For Break Char
				JR		Z, mainLoop_cont1   ; no key
                CP      $1B                 ; RUN/STOP?
                JR      Z, initBoard
                CP      $03                 ; CTRL-C?
                JR      Z, exit_program                   

mainLoop_cont1:
                LD      IX, board1          ;Board 1 is the old board  
                LD      HL, board2          ;Board 2 is the new board
                CALL    evolve              ;evolve into board 2

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

                CALL    MONITOR_QUICKCK     ;Check For Break Char
				JR		Z, mainLoop_cont2   ; no key
                CP      $1B                 ; RUN/STOP?
                JR      Z, initBoard
                CP      $03                 ; CTRL-C?
                JR      Z, exit_program

mainLoop_cont2:
                LD      IX, board2          ;Board 2 is the old board
                LD      HL, board1          ;Board 1 is the new board, point to second row
                CALL    evolve              ;evolve into board 1

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


DoReflections:
; IX = Source board
                PUSH    IX
                POP     IY
                LD      DE, WIDTH * (HEIGHT_WB - 1)   ; get us to bottom row
                ADD     IY, DE
; IX points to top row (bottom reflection)
; IY points to bottom row (top reflection)
                LD      B, WIDTH
ReflectionLoop:
                ;       copy (bottom row - 1) byte to top row byte
                LD      A, (IY - WIDTH)
                LD      (IX + 0), A

                ;       copy (top row + 1) byte to bottom row byte
                LD      A, (IX + WIDTH)
                LD      (IY + 0), A

                INC     IX
                INC     IY
                DJNZ    ReflectionLoop

; IX shoud now point to second row
                RET


;Evolve
; IX = src board
; HL = dest board
evolve:
                CALL    DoReflections          ;Finishes with IX on second row
                LD      DE, WIDTH              ;Sync up the dest pointer since 
                ADD     HL, DE                 ;  IX got bumped up a line in DoReflections
                LD      B,  HEIGHT             ;Height without upper and lower borders, we only do the interior
evolveRow:
                PUSH    BC                     ;Save height for later   

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

                ;Increment generation
                LD      HL, (nGeneration)      
                INC     HL
                LD      (nGeneration), HL

                RET


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
                ADD     A, (IX + (WIDTH + WIDTH - 1))   ;Pos 6
                ADD     A, (IX +  WIDTH)                ;Pos 7
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
                ADD     A, (IX - (WIDTH + WIDTH - 1))   ;Pos 3
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
                ADD     A, (IX - (WIDTH + 1))   ;Pos 1
                ADD     A, (IX -  WIDTH)        ;Pos 2
                ADD     A, (IX - (WIDTH - 1))   ;Pos 3
                ADD     A, (IX - 1)             ;Pos 4
                ADD     A, (IX + 1)             ;Pos 5
                ADD     A, (IX + (WIDTH - 1))   ;Pos 6
                ADD     A, (IX +  WIDTH)        ;Pos 7
                ADD     A, (IX + (WIDTH + 1))   ;Pos 8


evalCell:
                CP      3                       
                JR      Z, birth                ;Exactly 3, then birth
                JR      NC, death               ;More than 3, death by overpopulation
                CP      2
                JR      Z, maintain             ;Copies from the last generation
                                                ;Anything else, (0 or 1) dies from loneliness
death:
                LD      (HL), 0
                RET
maintain:
                LD      A, (IX + 0)             ;Self
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
                LD      DE, WIDTH           ;start at line 2 dont want to print puffer
                ADD     HL, DE
                LD      DE, SCREEN_BASE + WIDTH ;Set screen origin skipping first row (reflection border)
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
board1:         .storage    WIDTH * HEIGHT_WB
board2:         .storage    WIDTH * HEIGHT_WB

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
