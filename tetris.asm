################ CSC258H1F Winter 2024 Assembly Final Project ##################
# This file contains our implementation of Tetris.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
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

PIECE_COLOR:
    .word 0xff0000

GO_LEFT_KEY:
    .word 0x61
GO_RIGHT_KEY:
    .word 0x64
GO_UP_KEY:
    .word 0x77
GO_DOWN_KEY:
    .word 0x73
    
D:
    .word 0x64
U:
    .word 0x75
L:
    .word 0x6c
R:
    .word 0x72
    
newline: .asciiz "\n"


##############################################################################
# Mutable Data
##############################################################################

pieces: 
    .space 70
    
currentPiece:
    .space 10
    

##############################################################################
# Code
##############################################################################
	.text
	.globl main

	# Run the Tetris game.
main:
    # Allocate 8 bytes for x posn and store address in $s0 
    li $a0 4
    li $v0 9
    syscall
    add $s0, $v0, $zero

    # Store 0x0000 at address $s0
    addi $t0, $zero, 1
    sw $t0, 0($s0)
    
    # Allocate 8 bytes for y posn and store address in $s0 
    li $a0 4
    li $v0 9
    syscall
    add $s1, $v0, $zero

    # Store 0x0000 at address $s0
    addi $t0, $zero, 1
    sw $t0, 0($s1)
    
    # j END
    jal game_loop
    

game_loop:
    # 1a. Handle keypress
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal check_keyboard
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # 2a. Check for collisions
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal check_collisions
    lw $ra, 0($sp)
    addi $sp, $sp, 4

    # 2b. Update locations (paddle, ball)
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal update_locations
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # 3. Draw the screen
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_screens
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # 4. Sleep
    li 		$v0, 32
    li 		$a0, 10
    syscall

    b game_loop
	
	
check_keyboard:
    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t1, 0($t0)                  # Load first word from keyboard
    bne $t1, 1, no_key              # Don't call handle key unless first word is 1
    
    # Store $ra on stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Store keyboard adress on stack
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    
    jal handle_key
    
    # Pop return address off stack
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    no_key: 
        jr $ra
    
    
handle_key:
    # Grab keyboard address off stack
    lw $t0, 0($sp)
    addi $sp, $sp, 4
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
    #### PRINTING ####
    la $a0, L
    li $v0, 4                
    syscall
    la $a0, newline
    syscall
    syscall
    #### END PRINTING ####
     
    #### DECREMENT X
    lw $t2, 0($s0)
    beq $t2, 0, l_stationary
    subiu $t2, $t2, 1
    sw $t2, 0($s0)
        
    l_stationary:
    jr $ra
    
    
    right_key:
    #### PRINTING ####
    la $a0, R
    li $v0, 4                
    syscall
    la $a0, newline
    syscall
    syscall
    #### END PRINTING ####
     
    
    #### Increment X
    lw $t2, 0($s0)
    beq $t2, 31, r_stationary
    addiu $t2, $t2, 1
    sw $t2, 0($s0)
    
    r_stationary:
    jr $ra
    
    up_key: 
    ### PRINT OUT COMMAND
    la $a0, U 
    li $v0, 4
    syscall
    la $a0, newline 
    syscall
    
    #### Decrement y
    lw $t2, 0($s1)
    beq $t2, 0, r_stationary
    subiu $t2, $t2, 1
    sw $t2, 0($s1)
    
    u_stationary:
    jr $ra
        
    down_key: 
    la $a0, D
    li $v0, 4
    syscall
    la $a0, newline 
    la $a0, newline 
    syscall
    
    #### Increment y
    lw $t2, 0($s1)
    beq $t2, 31, r_stationary
    addiu $t2, $t2, 1
    sw $t2, 0($s1)
    
    d_stationary:
    jr $ra
    
move_piece:

    
    
    
    
#TODO BUILD THESE
check_collisions:
    jr $ra
update_locations:
    jr $ra
draw_screens:

    lw $t0, ADDR_DSPL       # $t0 = base address for display
    li $t1, 0xff0000        # $t1 = red
    lh $t2, 0($s0)          # Grab the x posn and put it in $t2
    lh $t3, 0($s1)          # Grab the y posn and put it in $t3
    
    ##### Set $t4 to 32*$t3 + $t2
    sll $t4, $t3, 7
    sll $t2, $t2, 2
    addu $t4, $t4, $t2
    addu $t4, $t4, $t0    

    sw $t1, 0($t4)          # paint the current position red
    
    jr $ra
    
    

END:
	li $v0, 10                      # Quit gracefully
	syscall

