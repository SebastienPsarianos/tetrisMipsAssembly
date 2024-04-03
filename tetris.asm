################ CSC258H1F Winter 2024 Assembly Final Project ##################
# This file contains our implementation of Tetris.
#
# Student 1: Sebastien Psarianos, 1008596119
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       TODO
# - Unit height in pixels:      TODO
# - Display width in pixels:    TODO
# - Display height in pixels:   TODO
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

#### Arena Size (32 * 32) * 1 byte colour code
arena: .word 0:1024

#### Store 8 colours with the last one being the grey
colours:
    .word 0x877B3C, 0xEFDD43, 0xBCA88D, 0x524566, 0x12144B, 0x5C0A0A, 0xB0B0B0, 0x000000

#### Store tetremino recipies in order I, J, L, Z, S, T, O
recipies:
    .byte 0b10101000, 0b10101101, 0b10100111,  0b10111000, 0b10011000, 0b10110110,  0b01101100
    
gameWidth:
    .byte 16
          
newline: .asciiz "\n"
##############################################################################
# Mutable Data
##############################################################################



#### Current piece (byte - xposn) (byte - yposn) (byte piece/orientation)
xPosn:
    .byte 0x0f
yPosn:
    .byte 0x00
    
#### idx of one of the recipies defined in recipies
piece:
    .byte 0
    
#### idx of one of the colours defined in colours
pieceColour:
    .byte 0
    
#### ammount of 90deg rotations from original poisition
orientation:
    .byte 0
    

#### Stores next move during pre-move checking (collision detecteion eg)
####    0 is no move, 
####    w,a,s,d key codes correspond to rotate, left, down, right. 
nextMove:
   .byte 0
   
#### block locks in place after move if this is true
lockBlock:
    .byte 0
    
loopNum: 
    .byte 0
    
gravitySpeed:
    .byte 128

##############################################################################
# Code
##############################################################################
	.text
	.globl main


#######################################
######### MAIN AND GAME LOOP ##########
#######################################
main:
    #### Sets up borders
    jal placeBorder
    jal getNewPiece
    jal game_loop

    jal END
    
game_loop:
    # 1a. Handle keypress
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    jal check_keyboard
    lw $ra, 0($sp)
    addiu $sp, $sp, 4

    # 2a. Check for collisions
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    jal check_collisions
    lw $ra, 0($sp)
    addiu $sp, $sp, 4

    # 2b. Update locations (paddle, ball)
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    jal updateLocations
    lw $ra, 0($sp)
    addiu $sp, $sp, 4

    # 3. Draw the screen
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_screens
    lw $ra, 0($sp)
    addiu $sp, $sp, 4

    # 4. Sleep
    li 		$v0, 32
    li 		$a0, 16
    syscall

    b game_loop

###################################
######### INITIALIZATION ##########
###################################
placeBorder:
    addiu $t1, $zero, 32 # y value counter
    y_loop:
        beq $t1 $zero exitBorder # Return to y loop when done
        addiu $t1 $t1 -1 # Decrement y
        addiu $t2, $zero, 32 # x value counter
        x_loop:
            beq $t2 $zero y_loop # Return to y loop when done
            addiu $t2 $t2 -1 # Decrement x
            
            lbu $t3 gameWidth
            subu $t3 $t2 $t3
            bgtz $t3, border # Check if x is > 31
            beq $t1 31 border # Check if y is 31
            beq $t2, 0, border # Check if x is zero

            ### BLCK SQUARE START
            addiu $sp, $sp, -4
            sw $ra, 0($sp)
            jal storeTemporaryRegisters

            #### Parameters
            li $t3 7
            addiu $sp, $sp, -12
            sw $t3 8($sp) # Store colour
            sw $t1 4($sp) # Store y posn
            sw $t2 0($sp) # Store x posn
            
            jal placeSquare
            
            #### Get rid of parameters
            addiu $sp $sp 12
            
            jal grabTemporaryRegisters
            lw $ra, 0($sp)
            addiu $sp, $sp, 4
        
            ### BLACK SQUARE END

            b x_loop
            border:
                addiu $sp, $sp, -4
                sw $ra, 0($sp)
                jal storeTemporaryRegisters
                
                addiu $sp $sp -12
                li $t3 6
                sw $t3 8($sp) # Store colour
                sw $t1 4($sp) # Store y posn
                sw $t2 0($sp) # Store x posn

                #### Draw the square
                jal placeSquare

                addiu $sp $sp 12
                
                jal grabTemporaryRegisters
                
                lw $ra, 0($sp)
                addiu $sp, $sp, 4

                b x_loop
        exitBorder:
            jr $ra

#####################################
######### Handle Keyboard  ##########
#####################################

#### If there is a key pressed put it in the next move for collision checking
check_keyboard:
    lw $t0 ADDR_KBRD               # $t0 = base address for keyboard
    la $t1 nextMove

    #### Grab loopNum and gravity speed
    la $t2 loopNum
    lbu $t3 gravitySpeed
    lbu $t4 0($t2)
    
    #### Increment gravity value and then store
    beq $t4 $t3 resetLoop
    addiu $t4 $t4 1
    sb $t4 0($t2)
    b gravityCheck
    resetLoop:
    addu $t4 $zero $zero
    sb $t4 0($t2)
    
    #### Check if gravity should push block this loop
    gravityCheck:
    lw $t2, 0($t0)                  # Load first word from keyboard into t2
    beq $t4 $t3 gravity
    bne $t2, 1, no_key

    lw $t3, 4($t0)                  # Grab second word
    
    #### Check for valid move
    beq $t3, 0x61, validCommand                 
    beq $t3, 0x64, validCommand            
    beq $t3, 0x77, validCommand           
    beq $t3, 0x73, validCommand     
    beq $t3, 0x71, END                      # Exit the game      
    
    no_key:
    addu $t3 $zero $zero
    sb $t3 0($t1)
    jr $ra
    
    gravity:
    li $t3, 0x73                  # Make next move down
    sb $t3 0($t1)
    jr $ra
    
    validCommand:
    sb $t3 0($t1)                 
    jr $ra
    

####################################
######### Check Collisions  ########
####################################

check_collisions:
    #### Grab orientation, piece, colour, x, y from memory
    lbu $t0 orientation
    lbu $t1 piece
    lbu $t2 pieceColour
    lbu $t3 yPosn
    lbu $t4 xPosn
    lbu $t5 nextMove  
    
    #### Store $ra till the end
    addiu $sp $sp -4
    sw $ra 0($sp)

    #### DELETE OLD PIECE POSITION
    jal storeTemporaryRegisters
    
    ### Set colour black
    addi $t6 $zero 7
    
    addiu $sp $sp -20
    sb $t0 16($sp) # Pass in orientation
    sb $t1 12($sp) # Pass in piece
    sb $t6 8($sp) # Pass in colour (Black)
    sb $t3 4($sp) # Pass in yPosn
    sb $t4 0($sp) # Pass in xPosn
    
    jal placePiece
    
    addiu  $sp $sp 20
    
    jal grabTemporaryRegisters
    
    #### END OLD PIECE DELETE
    beq $t5 0x00 skipChecks
    
    #### Args for getPieceLocations
    addiu  $sp $sp -20
    sb $t0 16($sp) # Pass in orientation
    sb $t1 12($sp) # Pass in piece
    sb $t5 8($sp) # Pass in nextMove
    sb $t3 4($sp) # Pass in yPosn
    sb $t4 0($sp) # Pass in xPosn
    
    ####  Block positions on stack (-20)
    jal getPieceLocations

    ##### SET nextMove to zero if collision found
    jal checkConflict
    beq $v0 1 blockMove

    #### If move is allowed check for blocks underneath
    jal checkUnder
    la $t9 lockBlock
    sb $v0 0($t9)
    
    #### If block is locked, check for completed rows
    beq $v0 0 dontCheckRows
    jal checkRows
    dontCheckRows:
    b checksComplete
    
    blockMove:
    la $t9 nextMove
    li $v0 0
    sb $v0 0($t9)
    
    checksComplete:
    addiu $sp $sp 40
    
    skipChecks:
    lw $ra 0($sp)
    addiu $sp $sp 4
    
    jr $ra
    
checkUnder:
    la $t0 arena
    addu $t1 $zero $zero
        
    checkBlockUnder:
        beq $t1 20 nothing_under
        
        #### Grab block position off stack
        addu $t2 $t1 $sp
        lw $t2 0($t2)
        
        #### Add to base arena value
        addu $t2 $t0 $t2
        
        #### Add 128 to get block underneath
        addiu $t2 $t2 128    

        lw $t2 0($t2)
        addi $t1 $t1 4
        
        #### Grab only colour code
        andi $t2 $t2 0x00ffffff
        beq $t2 0 checkBlockUnder
        li $v0 1
        
        jr $ra

    nothing_under:
    li $v0 0
    jr $ra
    
checkConflict:
    la $t0 arena
    addu $t1 $zero $zero
    
    check_block_conflict:
        beq $t1 20 no_conflicts
        
        #### Grab block position off stack
        addu $t2 $t1 $sp
        lw $t2 0($t2)
        
        #### Load arena value
        addu $t2 $t0 $t2
        lw $t2 0($t2)

        addi $t1 $t1 4
        
        #### Grab only colour code
        andi $t2 $t2 0x00ffffff
        beq $t2 0 check_block_conflict
        li $v0 1
        jr $ra

    no_conflicts:
    li $v0 0
    jr $ra
    
    
checkRows:
    li $v0 0
    la $t0 arena
    addu $t1 $zero $zero
        
    checkRow:
        beq $t1 20 allRowsChecked
        
        #### Grab block position off stack
        addu $t2 $t1 $sp
        lw $t2 0($t2)
        
        #### Right shift 7 then left shift 5 times to get only y value * 32
        srl $t2 $t2 7
        sll $t2 $t2 5
        
        addu $t3 $zero $zero
        lbu $t4 gameWidth
        
        checkSquare:
            #### Exit if all squares in row have been checked
            beq $t3 $t4 rowFull 
            #### Increment x
            addiu $t3 $t3 1
            
            # Calculate 4*(y*32 + x) to get offset
            addu $t5 $t3 $t2
            sll $t5 $t5 2
            addu $t5 $t5 $t0 # Grab address
            
            # Check if the square is black, if not check if this piece will fill the spot
            lw $t6 0($t5)
            beq $t6 0 rowNotFull
            
            #### Go through check to see if the new piece position will fill this spot
            addu $t7 $zero $zero
            checkPiece:
                #### If this is true, the square isn't filled by the piece
                beq $t7 20 rowNotFull
                
                #### Grab block position off stack
                addu $t2 $t7 $sp
                lw $t2 0($t2)
                
                #### Convert to address in arena
                addu $t2 $t2 $t0
                
                #### Check if this piece square $t2 will fill row spot $t5
                beq $t2 $t5 checkSquare
                
                #### Increment stack pointer
                addiu $t7 $t7 4

            b checkSquare
            
        rowNotFull:
        addiu $t1 $t1 4
        b checkRow
        
        rowFull:
        #### TODO add rows to delete
        li $v0 1
        
        allRowsChecked:
        jr $ra
    
getPieceLocations:
    lbu $t4, 0($sp)          # Pop x posn off stack and put in $t1
    lbu $t5, 4($sp)          # Pop y posn off stack and put in $t2
    lbu $t6, 8($sp)           # Pop reqMove idx off stack and put in $t3
    lbu $t7, 12($sp)         # Pop piece idx off stack and put in $t3
    lbu $t8, 16($sp)         # Pop orientation off stack and put in $t4

    beq $t6, 0x61, checkLeft                # Move the piece left
    beq $t6, 0x64, checkRight               # Move the piece right 
    beq $t6, 0x77, checkRotate              # Rotate the piece 
    beq $t6, 0x73, checkDown                # Move the piece down
    
    jr $ra
    
    checkLeft:
        addi $t4 $t4 -1
        b calculate
    checkRight:
        addi $t4 $t4 1
        b calculate
    checkRotate:
        addi $t8 $t8 1
        b calculate
    checkDown:
        addi $t5 $t5 1
        b calculate
    
    calculate:
    #### Store origin on stack
    sll $t0, $t5, 5
    addu $t0, $t0, $t4
    sll $t0, $t0, 2     #### Convert index to offset
    
    # Store origin on stack
    addiu $sp, $sp, -4
    sw $t0, 0($sp)
    
    #### Set up recipie
    la $t0 recipies
    addu $t7 $t7 $t0
    lbu $t7 0($t7)
    
    li $t2 0b11000000
    # num shifts
    li $t3 6
    #### At this point $t3 is num shifts, $t2 is the mask, $t7 is the recipie
    #### $t0 is frree for use
    probeLoop:
        beq $t2 0 probeLoopexit

        #### Apply mask to recipe 
        and $t0 $t2 $t7
        #### Shift direction code to least sig figs using idx
        srlv $t0 $t0 $t3

        #### Apply rotation by adding rotation num
        #### Then mask to elliminate carry
        addu $t0 $t0 $t8
        andi $t0 $t0 0b11

        #### Go to appropriate move
        beq $t0 0b00 probe_up
        beq $t0 0b01 probe_right
        beq $t0 0b10 probe_down
        beq $t0 0b11 probe_left
 
        # Change x or y coord for next placement
        probe_up:
        addu $t5 $t5 -1
        b probeComplete

        probe_right:
        addu $t4 $t4 1
        b probeComplete

        probe_down:
        addu $t5 $t5 1
        b probeComplete

        probe_left:
        addu $t4 $t4 -1
        
        probeComplete:
        
        sll $t0, $t5, 5
        addu $t0, $t0, $t4
        sll $t0, $t0, 2     #### Convert index to offset
        
        # Store position on stack
        addiu $sp, $sp, -4
        sw $t0, 0($sp)
        
        #### Decrement mask and idx
        addiu $t3 $t3 -2
        srl $t2, $t2, 2
        
        b probeLoop
        
    probeLoopexit:
    jr $ra
    
######################################
######### Update positions  ##########
######################################
updateLocations:
    #### Change orientation or position based on key
    lbu $t0 orientation
    lbu $t1 piece
    lbu $t2 pieceColour
    lbu $t3 yPosn
    lbu $t4 xPosn
    lbu $t5 nextMove
    
    beq $t5, 0x00, placePieceNewPosition    # Don't move the piece
    beq $t5, 0x61, move_left                # Move the piece left
    beq $t5, 0x64, move_right               # Move the piece right 
    beq $t5, 0x77, rotate                   # Rotate the piece 
    beq $t5, 0x73, move_down                # Move the piece down
    
    #### Update x and store new position in memory
    move_left: 
    addiu $t4 $t4 -1
    la $t6 xPosn
    sb $t4 0($t6)
    b placePieceNewPosition
    
    move_right: 
    addiu $t4 $t4 1
    la $t6 xPosn
    sb $t4 0($t6)
    b placePieceNewPosition
    
    rotate: 
    addiu $t0 $t0 1
    la $t6 orientation
    sb $t0 0($t6)
    b placePieceNewPosition
    
    move_down: 
    addiu $t3 $t3 1
    la $t6 yPosn
    sb $t3 0($t6)
    b placePieceNewPosition
    
    placePieceNewPosition:
    
    addiu $sp $sp -4
    sw $ra 0($sp)
    jal storeTemporaryRegisters
    
    addiu $sp $sp -20
    sb $t0 16($sp) # Pass in orientation
    sb $t1 12($sp) # Pass in piece
    sb $t2 8($sp) # Pass in colour
    sb $t3 4($sp) # Pass in yPosn
    sb $t4 0($sp) # Pass in xPosn
    
    jal placePiece
    
    addiu  $sp $sp 20
    
    jal grabTemporaryRegisters
    lw $ra 0($sp)
    addiu $sp $sp 4
    
    lbu $t6 lockBlock
    beq $t6, 0x1, lockTheBlock                # Lock the piece and generate a new one
    jr $ra 
     
    lockTheBlock:
    #### Generate all the values for the new piece
    #### Will be placed on next loop
    addiu $sp $sp -4
    sw $ra 0($sp)
    jal storeTemporaryRegisters
    jal getNewPiece
    jal grabTemporaryRegisters
    lw $ra 0($sp)
    addiu $sp $sp 4
    
    #### Unlock the next block
    la $t6 lockBlock
    li $t7 0
    sb $t7 0($t6)
    
    jr $ra
    
    
#### Get a random piece, colour and store at start position
getNewPiece:
    #### Grab a random colour idx and put it in $t1
    li $v0 42
    li $a0 0
    li $a1 6
    syscall
    add $t1 $a0 $zero

    #### Grab a random piece code and put it in $t2
    li $v0 42
    li $a0 0
    li $a1 7
    syscall
    add $t2 $a0 $zero
    
    #### Grab a random x position and put it in $t3
    li $v0 42
    li $a0 0
    li $a1 0xb
    syscall
    addi $t3 $a0 2
    
    la $t4 pieceColour
    la $t5 piece
    la $t6 xPosn
    la $t7 yPosn
    la $t8 orientation
    
    #### TODO REMOVE THIS ####
    li $t2 0
    #### END TODO ####

    #Random colour
    sb $t1 0($t4)
    # random piece
    sb $t2 0($t5)
    # random x posn
    sb $t3 0($t6)
    
    #### Initial position at y=0
    li $t5 0x01
    sb $t5 0($t7)
    
    ### Initial orientation 0
    li $t5 0
    sb $t9 0($t8)

    jr $ra

##################################
######### Draw Screens  ##########
##################################
draw_screens:
    li $t0 1024
    la $t1 arena
    lw $t2 ADDR_DSPL
    drawPixel:
        addiu $t0 $t0 -1
        
        sll $t3 $t0 2 # Gives offset 
        
        addu $t4 $t3 $t1 # Add offset to arena address
        
        lw $t5 0($t4) # Load arena value
        
        # #### Check if block needs to be updated
        andi $t6 $t5 0x11000000
        bne $t6 0x11000000 dontDraw
        
        # #### Remove update requirement by getting rid of 11
        addiu $t5 $t5 -0x11000000
        sw $t5 0($t4)
        
        addu $t6 $t3 $t2 # Add offset to bitmap
        sw $t5 0($t6) # Store display value in bitmap
        
        dontDraw:
        beq $t0 $zero exitDraw
        b drawPixel
        
    exitDraw:
    jr $ra


########################################
######### Placing utiltities  ##########
########################################
    
placeSquare:
    #### Stack should contain
    # x posn
    # y posn
    # colour
    la $t0, arena

    lbu $t1, 0($sp)          # Pop x posn off stack and put in $t1
    lbu $t2, 4($sp)          # Pop y posn off stack and put in $t2
    lbu $t3, 8($sp)          # Pop colour idx off stack and put in $t3

    ##### Set $t4 to 32*$t2 + $t1 (with additional *4 to accomodate width of word) (gives position on screen)
    sll $t4, $t2, 5
    addu $t4, $t4, $t1
    sll $t4, $t4, 2     #### Convert index to offset

    #### Add to display start address
    addu $t4, $t4, $t0

    #### Calculate colour code location from base ($s1 + idx * 4)
    la $t5 colours
    sll $t3 $t3 2 #### Calculate offset
    add $t5 $t5 $t3
    # Load colour code from memory
    lw $t5, 0($t5)
    # Paint the current position with appropriate colour plus 
    # ff at the start to indicate it needs to be repainted
    addi $t5 $t5 0x11000000
    sw $t5, 0($t4)

    jr $ra


placePiece:
    lbu $t0, 0($sp)          # Pop x posn off stack and put in $t0
    lbu $t1, 4($sp)          # Pop y posn off stack and put in $t1
    lbu $t2, 8($sp)           # Pop colour idx off stack and put in $t2
    lbu $t3, 12($sp)         # Pop piece idx off stack and put in $t3
    lbu $t4, 16($sp)         # Pop orientation off stack and put in $t4

    ##### START BY Placing ORIGIN
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    jal storeTemporaryRegisters

    addiu $sp $sp -12
    sw $t2 8($sp) # Pass in colour
    sw $t1 4($sp) # Pass in y
    sw $t0 0($sp) # Pass in x

    jal placeSquare

    #### Move params off stack
    addiu $sp $sp 12

    jal grabTemporaryRegisters
    lw $ra, 0($sp)
    addiu $sp, $sp, 4


    #### Cursor to place with
    # X
    addu $t8 $zero $t0
    # Y
    addu $t9 $zero $t1

    #### Convert $t3 from piece number to piece recipie
    #### Move 
    la $t5 recipies
    addu $t5 $t3 $t5
    lbu $t3 0($t5)

    li $t5 0b11000000
    # num shifts
    li $t6 6
    placeLoop:

        beq $t5 0 placeLoopexit
        
        addiu $sp, $sp, -4
        sw $ra, 0($sp)
        jal storeTemporaryRegisters
    
        addiu $sp, $sp, -28
        sw $t4 24($sp)          # orientation
        sw $t2 20($sp)          # colour
        sw $t9 16($sp)          # cursorY
        sw $t8 12($sp)          # cursorX 
        sw $t3 8($sp)           # recipie
        sw $t6 4($sp)           # Idx (num shifts)
        sw $t5 0($sp)           # Mask
        
        jal placeSquareFromRecipe
        
        addiu $sp, $sp, 28
        
        jal grabTemporaryRegisters
        lw $ra, 0($sp)
        addiu $sp, $sp, 4
        
        #### Grab new cursors 
        add $t8 $v0 $zero
        add $t9 $v1 $zero
        
        #### Shift of mask output goes down by two
        #### Mask shifted by two
        addiu $t6 $t6 -2
        srl $t5, $t5, 2
        b placeLoop

    placeLoopexit:
    jr $ra

#### Need mask $t0, idx $t1, recipe $t2, cursorX $t3, cursorY $t4, colour $t5, orientation $t6
#### Moves cursor based on (mask, idx, recipie, cursorX, cursorY)
#### Draws square at position relative to the previous based on cursorX, cursorY, recipie and colour
placeSquareFromRecipe:
        lbu $t0, 0($sp)          # Mask
        lbu $t1, 4($sp)          # Idx (num shifts)
        lbu $t2, 8($sp)          # recipie
        lbu $t3, 12($sp)         # cursorX 
        lbu $t4, 16($sp)         # cursorY
        lbu $t5, 20($sp)         # colour
        lbu $t6, 24($sp)         # orientation
        

        #### Apply mask $t0 to recipie $t2 and put in $t7
        and $t7 $t2 $t0
        #### Shift direction code to least sig figs using idx
        srlv $t7 $t7 $t1

        #### Apply rotation by adding rotation num
        #### Then mask to elliminate carry
        addu $t7 $t7 $t6
        andi $t7 $t7 0b11

        #### Go to appropriate move
        beq $t7 0b00 calc_up
        beq $t7 0b01 calc_right
        beq $t7 0b10 calc_down
        beq $t7 0b11 calc_left

        calc_up:
        addu $t4 $t4 -1
        b placeComplete

        calc_right:
        addu $t3 $t3 1
        b placeComplete

        calc_down:
        addu $t4 $t4 1
        b placeComplete

        calc_left:
        addu $t3 $t3 -1
        b placeComplete

        placeComplete:
        
        addiu $sp, $sp, -4
        sw $ra, 0($sp)
        jal storeTemporaryRegisters
        

        addiu $sp, $sp, -12
        sw $t5 8($sp) # Pass in colour
        sw $t4 4($sp) # Pass in cursor y
        sw $t3 0($sp) # Pass in cursor x

        jal placeSquare

        #### Move params off stack
        addiu $sp $sp 12

        jal grabTemporaryRegisters
        lw $ra, 0($sp)
        addiu $sp, $sp, 4
        
        add $v0 $t3 $zero
        add $v1 $t4 $zero
        
        jr $ra
        
    
#################################
######### Stack Utils  ##########
#################################
storeTemporaryRegisters: 

    addiu $sp, $sp, -40
    sw $t0 36($sp) # Store $t0
    sw $t1 32($sp) # Store $t1
    sw $t2 28($sp) # Store $t2
    sw $t3 24($sp) # Store $t3
    sw $t4 20($sp) # Store $t4
    sw $t5 16($sp) # Store $t5
    sw $t6 12($sp) # Store $t6
    sw $t7 8($sp) # Store $t7
    sw $t8 4($sp) # Store $t8
    sw $t9 0($sp) # Store $t9
        
    jr $ra
    
    
grabTemporaryRegisters: 

    lw $t9, 0($sp) # Grab $t9
    lw $t8, 4($sp) # Grab $t8
    lw $t7, 8($sp) # Grab $t7
    lw $t6, 12($sp) # Grab $t6
    lw $t5, 16($sp) # Grab $t5
    lw $t4, 20($sp) # Grab $t4
    lw $t3, 24($sp) # Grab $t3
    lw $t2, 28($sp) # Grab $t2
    lw $t1, 32($sp) # Grab $t1
    lw $t0, 36($sp) # Grab $t0
    addiu $sp, $sp, 40

    jr $ra


END:
	li $v0, 10
	syscall