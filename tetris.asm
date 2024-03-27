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
####    ff is lock piece
nextMove:
   .byte 0x00

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
    li 		$a0, 1
    syscall

    b game_loop

###################################
######### INITIALIZATION ##########
###################################
placeBorder:
    addiu $t1, $zero, 32 # y value counter
    y_loop:
        beq $t1 $zero exit_arena # Return to y loop when done
        addiu $t1 $t1 -1 # Decrement y
        addiu $t2, $zero, 32 # x value counter
        x_loop:

            beq $t2 $zero y_loop # Return to y loop when done
            addiu $t2 $t2 -1 # Decrement x

            beq $t2, 31, border # Check if x is 31
            beq $t1 31 border # Check if y is 31
            beq $t2, 0, border # Check if x is zero

            ### BLCK SQUARE START
            addiu $sp, $sp, -28
            sw $ra, 24($sp) # Store return address
            sw $t0, 20($sp) # Store $t0
            sw $t1, 16($sp) # Store $t1
            sw $t2, 12($sp) # Store $t2
            li $t3 7
            sw $t3 8($sp) # Store colour
            sw $t1 4($sp) # Store y posn
            sw $t2 0($sp) # Store x posn

            #### Draw the square
            jal placeSquare

            addiu $sp $sp 12

            lw $t2, 0($sp) # Grab t2
            lw $t1, 4($sp) # Grab $t1
            lw $t0, 8($sp) # Grab $t0
            lw $ra, 12($sp) # Grab $ra
            addiu $sp, $sp, 16
            ### BLACK SQUARE END

            b x_loop
            border:
                addiu $sp, $sp, -28
                sw $ra, 24($sp) # Store return address
                sw $t0, 20($sp) # Store $t0
                sw $t1, 16($sp) # Store $t1
                sw $t2, 12($sp) # Store $t2
                li $t3 6
                sw $t3 8($sp) # Store colour
                sw $t1 4($sp) # Store y posn
                sw $t2 0($sp) # Store x posn

                #### Draw the square
                jal placeSquare

                addiu $sp $sp 12

                lw $t2, 0($sp) # Grab t2
                lw $t1, 4($sp) # Grab $t1
                lw $t0, 8($sp) # Grab $t0
                lw $ra, 12($sp) # Grab $ra
                addiu $sp, $sp, 16

                b x_loop
        exit_arena:
            jr $ra

#####################################
######### Handle Keyboard  ##########
#####################################
check_keyboard:
    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t1, 0($t0)                  # Load first word from keyboard
    bne $t1, 1, no_key              # Don't call handle key unless first word is 1

    # Store $ra on stack
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    # Store keyboard adress on stack
    addiu $sp, $sp, -4
    sw $t0, 0($sp)

    jal handle_key

    # Pop return address off stack
    lw $ra, 0($sp)
    addiu $sp, $sp, 4

    no_key:
        jr $ra


handle_key:
    # Grab keyboard address off stack
    lw $t0, 0($sp)
    addiu $sp, $sp, 4
	lw $t1, 4($t0)                 # Load second word into $t1

	##### $t1 is the current key. Do what you gotta do #####
	## Check which key is pressed
    beq $t1, 0x61, left_key
    beq $t1, 0x64, right_key
    beq $t1, 0x77, up_key
    beq $t1, 0x73, down_key
    beq $t1, 0x71, END
    jr $ra

    left_key:
    #### DECREMENT X
    la $t2 xPosn
    lbu $t3 0($t2)
    beq $t3, 1, l_stationary
    addiu $t3, $t3, -1
    sb $t3, 0($t2)
    l_stationary:
    jr $ra


    right_key:
    #### Increment X
    la $t2 xPosn
    lbu $t3 0($t2)
    beq $t3, 30, r_stationary
    addiu $t3, $t3, 1
    sb $t3, 0($t2)
    r_stationary:
    jr $ra

    down_key:
    #### Increment y
    la $t2 yPosn
    lbu $t3 0($t2)
    beq $t3, 30, d_stationary
    addiu $t3, $t3, 1
    sb $t3, 0($t2)
    d_stationary:
    jr $ra

    up_key:
    la $t2 orientation
    lbu $t3 0($t2)
    addiu $t3, $t3, 1
    sb $t3, 0($t2)
    jr $ra
    
####################################
######### Check Collisions  ########
####################################

check_collisions:
    jr $ra
    
    
######################################
######### Update positions  ##########
######################################
updateLocations:
    addiu $sp $sp -4
    sw $ra 0($sp)
    jal placeBorder
    lw $ra 0($sp)
    addiu $sp $sp 4

    addiu $sp $sp -4
    sw $ra 0($sp)
    jal placePiece
    lw $ra 0($sp)
    addiu $sp $sp 4
    jr $ra

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
    # Paint the current position with appropriate colour
    sw $t5, 0($t4)

    jr $ra


placePiece:
    la $t0 xPosn
    lbu $t0 0($t0)

    la $t1 yPosn
    lbu $t1 0($t1)

    la $t2 pieceColour
    lbu $t2 0($t2)

    la $t3 piece
    lbu $t3 0($t3)

    la $t4 orientation
    lbu $t4 0($t4)


    ##### START BY Placing ORIGIN
    addiu $sp, $sp, -24
    sw $ra 20($sp) # Store return address
    sw $t0 16($sp) # Store $t0
    sw $t1 12($sp) # Store $t1
    sw $t2 8($sp) # Store $t2
    sw $t3 4($sp) # Store $t3
    sw $t4 0($sp)

    addiu $sp $sp -12
    sw $t2 8($sp) # Pass in colour
    sw $t1 4($sp) # Pass in cursor y
    sw $t0 0($sp) # Pass in cursor x

    jal placeSquare

    #### Move params off stack
    addiu $sp $sp 12

    lw $t4 0($sp)
    lw $t3, 4($sp) # Grab $t3
    lw $t2, 8($sp) # Grab $t2
    lw $t1, 12($sp) # Grab $t1
    lw $t0, 16($sp) # Grab $t0
    lw $ra, 20($sp) # Grab $ra
    addiu $sp, $sp, 24


    #### Cursor to place with
    # X
    addu $t8 $zero $t0
    # Y
    addu $t9 $zero $t1

    #### Convert $t3 from piece number to piece recipie
    #### Move 
    la $t0 recipies
    addu $t0 $t0 $t3
    lbu $t3 0($t0)

    li $t5 0b11000000
    # num shifts
    li $t6 6
    placeLoop:

        beq $t5 0 placeLoopexit

        addiu $sp, $sp, -24
        sw $ra 20($sp) # Store return address
        sw $t0 16($sp) # Store $t0
        sw $t1 12($sp) # Store $t1
        sw $t2 8($sp) # Store $t2
        sw $t3 4($sp) # Store $t3
        sw $t4 0($sp)

        #### Apply mask $t5 to piece $t3 and put in $t7
        and $t7 $t3 $t5
        #### Shift direction code to least sig figs
        srlv $t7 $t7 $t6

        #### Apply rotation by adding rotation num
        #### Then mask to elliminate carry
        addu $t7 $t7 $t4
        andi $t7 $t7 0b11

        #### Go to appropriate move

        beq $t7 0b00 calc_up
        beq $t7 0b01 calc_right
        beq $t7 0b10 calc_down
        beq $t7 0b11 calc_left

        calc_up:
        addu $t9 $t9 -1
        b placeComplete

        calc_right:
        addu $t8 $t8 1
        b placeComplete

        calc_down:
        addu $t9 $t9 1
        b placeComplete

        calc_left:
        addu $t8 $t8 -1
        b placeComplete

        placeComplete:
        
        addiu $sp, $sp, -28
        sw $t8 24($sp)  # Store cursor x
        sw $t9 20($sp) # Store cursor y
        sw $t5 16($sp) # Store mask
        sw $t6 12($sp) # Store idx

        sw $t2 8($sp) # Pass in colour
        sw $t9 4($sp) # Pass in cursor y
        sw $t8 0($sp) # Pass in cursor x

        jal placeSquare

        #### Move params off stack
        addiu $sp $sp 12


        lw $t6 0($sp) # Grab idx
        lw $t5 4($sp) # Grab mask
        lw $t9 8($sp) # Grab cursor y
        lw $t8 12($sp) # Grab cursor x
        addiu $sp $sp 16

        lw $t4 0($sp)
        lw $t3, 4($sp) # Grab $t3
        lw $t2, 8($sp) # Grab $t2
        lw $t1, 12($sp) # Grab $t1
        lw $t0, 16($sp) # Grab $t0
        lw $ra, 20($sp) # Grab $ra
        addiu $sp, $sp, 24

        #### Shift of mask output goes down by two
        #### Mask shifted by two

        addiu $t6 $t6 -2
        srl $t5, $t5, 2
        b placeLoop

    placeLoopexit:
    jr $ra
    
    
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

    la $t3 pieceColour
    la $t4 piece
    la $t5 xPosn
    la $t6 yPosn

    sb $t1 0($t3)
    sb $t2 0($t4)

    li $t3 0x0f
    li $t4 0

    sb $t3 0($t5)
    sb $t4 0($t6)

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
        lw $t4 0($t4) # Load arena value
        
        addu $t5 $t3 $t2 # Add offset to bitmap
        sw $t4 0($t5) # Store display value in bitmap
        
        beq $t0 $zero exitDraw
        b drawPixel
        
    exitDraw:
    jr $ra


    
    



END:
	li $v0, 10
	syscall

