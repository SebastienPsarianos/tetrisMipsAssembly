
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
