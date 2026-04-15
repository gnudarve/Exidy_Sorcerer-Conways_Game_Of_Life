; ================================================================
; Conway's Game of Life for the Exidy Sorcerer
; No top/bottom reflection-copy pass
; Top/bottom wrap handled directly in evolve row processing
; ================================================================

    .format  "PRG"
    .setting "OutputSaveIndividualSegments", false


; ------------------------------------------------
; Board layout
;   Width includes left/right blank border columns
;   Height is playable rows only
;   Height_wb includes top/bottom blank display rows
; ------------------------------------------------
WIDTH               .equ 64
HEIGHT              .equ 30 - 2
HEIGHT_WB           .equ HEIGHT + 2

GENSBEFORERNDRESET  .equ 128
RNDRESETTHRESH      .equ 1

ROW_BYTES           .equ WIDTH
TOP_PLAY_ROW_OFF    .equ WIDTH
ROW2_OFF            .equ WIDTH * 2
ROW27_OFF           .equ WIDTH * 27
ROW28_OFF           .equ WIDTH * 28
BOTTOM_ROW_OFF      .equ WIDTH * (HEIGHT_WB - 1)

COL1_OFF            .equ 1
COL2_OFF            .equ 2
COL61_OFF           .equ WIDTH - 3
COL62_OFF           .equ WIDTH - 2
COL63_OFF           .equ WIDTH - 1

    .segment "CODE"
    .org $0000

; ================================================================
; initBoard
; ================================================================
initBoard:
                LD      HL, board1
                CALL    inputBlankRow       ; row 0 blank

                LD      B, HEIGHT
initBoardRow:
                PUSH    BC

                LD      (HL), 0             ; left border
                INC     HL

                LD      B, WIDTH - 2        ; playable cells
initBoardCell:
                CALL    RandLFSR
                CP      256 / 4             ; 25% alive
                LD      (HL), 0
                JP      NC, cellDead
                INC     (HL)
cellDead:
                INC     HL
                DJNZ    initBoardCell

                LD      (HL), 0             ; right border
                INC     HL

                POP     BC
                DJNZ    initBoardRow

                CALL    inputBlankRow       ; row 29 blank

                ; Clear board2 as well so first alternate frame is clean
                LD      HL, board2
                CALL    inputBlankRow

                LD      B, HEIGHT
initBoardRow2:
                PUSH    BC

                LD      (HL), 0
                INC     HL

                LD      B, WIDTH - 2
initBoardCell2:
                LD      (HL), 0
                INC     HL
                DJNZ    initBoardCell2

                LD      (HL), 0
                INC     HL

                POP     BC
                DJNZ    initBoardRow2

                CALL    inputBlankRow

                LD      HL, 0
                LD      (nGeneration), HL

mainLoop:
                LD      HL, board1
                CALL    printBoard

                CALL    MONITOR_QUICKCK
                JR      Z, mainLoop_cont1
                CP      $1B                 ; RUN/STOP
                JR      Z, initBoard
                CP      $03                 ; CTRL-C
                JR      Z, exit_program

mainLoop_cont1:
                LD      IX, board1          ; source
                LD      HL, board2          ; dest
                CALL    evolve

                LD      HL, board2
                CALL    printBoard

                CALL    MONITOR_QUICKCK
                JR      Z, mainLoop_cont2
                CP      $1B
                JR      Z, initBoard
                CP      $03
                JR      Z, exit_program

mainLoop_cont2:
                LD      IX, board2          ; source
                LD      HL, board1          ; dest
                CALL    evolve

                LD      HL, (nGeneration)
                LD      DE, GENSBEFORERNDRESET
                OR      A
                SBC     HL, DE
                JP      C, mainLoop

                CALL    RandLFSR
                CP      RNDRESETTHRESH
                JP      C, initBoard

                JP      mainLoop

exit_program:
                RET


; ================================================================
; evolve
;
; IN:
;   IX = source board base
;   HL = destination board base
; ================================================================
evolve:
                ; Save base pointers
                PUSH    IX
                POP     DE
                LD      (pSrcBase), DE
                LD      (pDstBase), HL

                ; blank top row in destination
                LD      HL, (pDstBase)
                CALL    inputBlankRow

                ; -------- top playable row (row 1) --------
                ; prev = row 28, cur = row 1, next = row 2, dst = row 1
                LD      HL, (pSrcBase)
                LD      DE, ROW28_OFF
                ADD     HL, DE
                LD      (pPrevRow), HL

                LD      HL, (pSrcBase)
                LD      DE, TOP_PLAY_ROW_OFF
                ADD     HL, DE
                LD      (pCurRow), HL

                LD      HL, (pSrcBase)
                LD      DE, ROW2_OFF
                ADD     HL, DE
                LD      (pNextRow), HL

                LD      HL, (pDstBase)
                LD      DE, TOP_PLAY_ROW_OFF
                ADD     HL, DE
                LD      (pDstRow), HL

                CALL    processOneRow

                ; -------- middle playable rows (2..27) --------
                LD      B, HEIGHT - 2       ; 26 rows
evolveMidRows:
                CALL    advanceRowPointers
                CALL    processOneRow
                DJNZ    evolveMidRows

                ; -------- bottom playable row (row 28) --------
                ; prev = row 27, cur = row 28, next = row 1, dst = row 28
                LD      HL, (pSrcBase)
                LD      DE, ROW27_OFF
                ADD     HL, DE
                LD      (pPrevRow), HL

                LD      HL, (pSrcBase)
                LD      DE, ROW28_OFF
                ADD     HL, DE
                LD      (pCurRow), HL

                LD      HL, (pSrcBase)
                LD      DE, TOP_PLAY_ROW_OFF
                ADD     HL, DE
                LD      (pNextRow), HL

                LD      HL, (pDstBase)
                LD      DE, ROW28_OFF
                ADD     HL, DE
                LD      (pDstRow), HL

                CALL    processOneRow

                ; blank bottom row in destination
                LD      HL, (pDstBase)
                LD      DE, BOTTOM_ROW_OFF
                ADD     HL, DE
                CALL    inputBlankRow

                ; generation++
                LD      HL, (nGeneration)
                INC     HL
                LD      (nGeneration), HL
                RET


; ================================================================
; advanceRowPointers
;   prev += WIDTH
;   cur  += WIDTH
;   next += WIDTH
;   dst  += WIDTH
; ================================================================
advanceRowPointers:
                LD      HL, (pPrevRow)
                LD      DE, ROW_BYTES
                ADD     HL, DE
                LD      (pPrevRow), HL

                LD      HL, (pCurRow)
                LD      DE, ROW_BYTES
                ADD     HL, DE
                LD      (pCurRow), HL

                LD      HL, (pNextRow)
                LD      DE, ROW_BYTES
                ADD     HL, DE
                LD      (pNextRow), HL

                LD      HL, (pDstRow)
                LD      DE, ROW_BYTES
                ADD     HL, DE
                LD      (pDstRow), HL
                RET


; ================================================================
; processOneRow
;   Uses pPrevRow / pCurRow / pNextRow / pDstRow
;   Writes:
;     dst col0  = 0
;     dst col1  = left special
;     dst col2..61 = middle
;     dst col62 = right special
;     dst col63 = 0
; ================================================================
processOneRow:
                ; left border blank
                LD      HL, (pDstRow)
                LD      (HL), 0

                ; left edge playable cell (col 1)
                CALL    calcCell_Left_NoReflect

                ; initialize middle pointers for col 2..61
                LD      HL, (pPrevRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                LD      (pPrevPtr), HL

                LD      HL, (pCurRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                LD      (pCurPtr), HL

                LD      HL, (pNextRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                LD      (pNextPtr), HL

                LD      HL, (pDstRow)
                LD      DE, COL2_OFF
                ADD     HL, DE
                LD      (pDstPtr), HL

                LD      B, WIDTH - 4        ; cols 2..61 = 60 cells
processMidLoop:
                CALL    calcCell_Mid_NoReflect
                DJNZ    processMidLoop

                ; right edge playable cell (col 62)
                CALL    calcCell_Right_NoReflect

                ; right border blank
                LD      HL, (pDstRow)
                LD      DE, COL63_OFF
                ADD     HL, DE
                LD      (HL), 0
                RET


; ================================================================
; calcCell_Left_NoReflect
;   target = col 1
;   left wraps to col 62
; ================================================================
calcCell_Left_NoReflect:
                XOR     A

                ; prev row: 62,1,2
                LD      HL, (pPrevRow)
                LD      DE, COL62_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pPrevRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pPrevRow)
                LD      DE, COL2_OFF
                ADD     HL, DE
                ADD     A, (HL)

                ; cur row: 62,2
                LD      HL, (pCurRow)
                LD      DE, COL62_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pCurRow)
                LD      DE, COL2_OFF
                ADD     HL, DE
                ADD     A, (HL)

                ; next row: 62,1,2
                LD      HL, (pNextRow)
                LD      DE, COL62_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pNextRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pNextRow)
                LD      DE, COL2_OFF
                ADD     HL, DE
                ADD     A, (HL)

                ; self = cur row col1
                LD      HL, (pCurRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                LD      D, (HL)

                ; dst = dst row col1
                LD      HL, (pDstRow)
                LD      DE, COL1_OFF
                ADD     HL, DE

                JP      evalCell_A_D_to_HL


; ================================================================
; calcCell_Mid_NoReflect
;   current destination cell is pDstPtr
;   pPrevPtr / pCurPtr / pNextPtr point to x-1
; ================================================================
calcCell_Mid_NoReflect:
                XOR     A

                ; prev row: x-1, x, x+1
                LD      HL, (pPrevPtr)
                ADD     A, (HL)
                INC     HL
                ADD     A, (HL)
                INC     HL
                ADD     A, (HL)

                ; cur row: x-1, x+1
                LD      HL, (pCurPtr)
                ADD     A, (HL)
                INC     HL
                INC     HL
                ADD     A, (HL)

                ; next row: x-1, x, x+1
                LD      HL, (pNextPtr)
                ADD     A, (HL)
                INC     HL
                ADD     A, (HL)
                INC     HL
                ADD     A, (HL)

                ; self = cur row x
                LD      HL, (pCurPtr)
                INC     HL
                LD      D, (HL)

                ; dst addr = pDstPtr
                LD      HL, (pDstPtr)
                CALL    evalCell_A_D_to_HL

                ; advance ptrs by 1
                LD      HL, (pPrevPtr)
                INC     HL
                LD      (pPrevPtr), HL

                LD      HL, (pCurPtr)
                INC     HL
                LD      (pCurPtr), HL

                LD      HL, (pNextPtr)
                INC     HL
                LD      (pNextPtr), HL

                LD      HL, (pDstPtr)
                INC     HL
                LD      (pDstPtr), HL

                RET


; ================================================================
; calcCell_Right_NoReflect
;   target = col 62
;   right wraps to col 1
; ================================================================
calcCell_Right_NoReflect:
                XOR     A

                ; prev row: 61,62,1
                LD      HL, (pPrevRow)
                LD      DE, COL61_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pPrevRow)
                LD      DE, COL62_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pPrevRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                ADD     A, (HL)

                ; cur row: 61,1
                LD      HL, (pCurRow)
                LD      DE, COL61_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pCurRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                ADD     A, (HL)

                ; next row: 61,62,1
                LD      HL, (pNextRow)
                LD      DE, COL61_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pNextRow)
                LD      DE, COL62_OFF
                ADD     HL, DE
                ADD     A, (HL)

                LD      HL, (pNextRow)
                LD      DE, COL1_OFF
                ADD     HL, DE
                ADD     A, (HL)

                ; self = cur row col62
                LD      HL, (pCurRow)
                LD      DE, COL62_OFF
                ADD     HL, DE
                LD      D, (HL)

                ; dst = dst row col62
                LD      HL, (pDstRow)
                LD      DE, COL62_OFF
                ADD     HL, DE

                JP      evalCell_A_D_to_HL


; ================================================================
; evalCell_A_D_to_HL
;   A = neighbor count
;   D = self
;   HL = destination address
; ================================================================
evalCell_A_D_to_HL:
                CP      3
                JR      Z, birth
                JR      NC, death           ; 4..8
                CP      2
                JR      Z, maintain
death:
                LD      (HL), 0
                RET
maintain:
                LD      A, D
                LD      (HL), A
                RET
birth:
                LD      (HL), 1
                RET


; ================================================================
; inputBlankRow
;   HL = row start
; ================================================================
inputBlankRow:
                LD      B, WIDTH
inputBlankRowLoop1:
                LD      (HL), 0
                INC     HL
                DJNZ    inputBlankRowLoop1
                RET


; ================================================================
; printBoard
;   HL = board base
; ================================================================
printBoard:
                LD      DE, SCREEN_BASE
                LD      B, HEIGHT_WB
printRow:
                PUSH    BC
                LD      B, WIDTH
printCell:
                LD      A, (HL)
                AND     A
                JR      Z, printDead
printAlive:
                LD      A, 132
                JP      printCont
printDead:
                LD      A, ' '
printCont:
                LD      (DE), A
                INC     DE
                INC     HL
                DJNZ    printCell

                POP     BC
                DJNZ    printRow
                RET


; ================================================================
; RandLFSR
;   returns pseudo-random byte in A
; ================================================================
RandLFSR:
                PUSH    HL
                PUSH    BC

                LD      HL, LFSRSeed+4
                LD      E, (HL)
                INC     HL
                LD      D, (HL)
                INC     HL
                LD      C, (HL)
                INC     HL
                LD      A, (HL)
                LD      B, A

                RL      E
                RL      D
                RL      C
                RLA

                RL      E
                RL      D
                RL      C
                RLA

                RL      E
                RL      D
                RL      C
                RLA
                LD      H, A

                RL      E
                RL      D
                RL      C
                RLA

                XOR     B

                RL      E
                RL      D

                XOR     H
                XOR     C
                XOR     D

                LD      HL, LFSRSeed+6
                LD      DE, LFSRSeed+7
                LD      BC, 7
                LDDR
                LD      (DE), A

                POP     BC
                POP     HL
                RET


    .segment "DATA"

LFSRSeed:       .byte   $2A,$C3,$14,$C2,$8D,$59,$B1,$88
nGeneration:    .word   0

; base pointers
pSrcBase:       .word   0
pDstBase:       .word   0

; row pointers
pPrevRow:       .word   0
pCurRow:        .word   0
pNextRow:       .word   0
pDstRow:        .word   0

; working pointers for middle-of-row processing
pPrevPtr:       .word   0
pCurPtr:        .word   0
pNextPtr:       .word   0
pDstPtr:        .word   0

board1:         .storage WIDTH * HEIGHT_WB
board2:         .storage WIDTH * HEIGHT_WB

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