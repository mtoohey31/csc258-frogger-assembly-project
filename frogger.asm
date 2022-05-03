# vi: commentstring=#%s
#####################################################################
#
# CSC258H5S Fall 2021 Assembly Final Project
# University of Toronto, St. George
#
# Student: Matthew Toohey
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1
# - Milestone 2
# - Milestone 3
# - Milestone 4
# - Milestone 5
#
# Which approved additional features have been implemented?
# - Easy Features (3):
#   - Display the number of lives remaining
#   - Dynamic increase in difficulty
#   - Different rows move at different speeds
# - Hard Features (2):
#   - Add sound effects for movement, collisions, game end and reaching the goal area
#   - Display the player's score at the top of the screen
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################

# data {{{
.data
        displayAddress: .word 0x10008000
        keystrokeOccurredAddress: .word 0xffff0000
        keystrokeValueAddress: .word 0xffff0004

        frogPosition: .word 0x00007038
        previousFrogPosition: .word 0x00007038
        logPositions: .word 0x8c3c460a
        carPositions: .word 0x3c8c1450
        lives: .byte 3
        endRegions: .word 0x00000000

        tickDelay: .byte 17 # the delay between ticks in ms

        heartColour: .word 0xe8472e
        rocksColour: .word 0x5e5e5e
        grassColour: .word 0x07c158
        roadColour: .word 0xc1c1c1
        carColour: .word 0xd61717
        waterColour: .word 0x3496d8
        logColour: .word 0x84590f
        frogColour: .word 0xeae023
# }}}
# macros {{{
.macro push_ra
        addi $sp, $sp, -4
        sw $ra, 0($sp)
.end_macro

.macro pop_ra
        lw $ra, 0($sp)
        addi $sp, $sp, 4
.end_macro

.macro drop_bits (%r, %d)
        srl %r, %r, %d
        sll %r, %r, %d
.end_macro
# }}}
.text
# start {{{
main:
        jal INITIAL_DRAW
# }}}
# loops {{{
LOOP: # the main game loop
        jal MOVE_FROG
        jal MOVE_OBJS
        jal CHECK_COLLISIONS
        jal DRAW
        jal SLEEP
        j LOOP
# }}}
# movement {{{
MOVE_FROG: # check for input and move (or don't move) the frog accordingly
        lw $t0, keystrokeOccurredAddress # load the memory address that stores whether a keystroke has happened into $t0
        lw $t1, 0($t0) # load whether a keyboard event has occurred into $t5
        bne $t1, 1, RETURN # if none has occurred, return
        lw $t0, keystrokeValueAddress # load the memory address that stores the keystroke into $t0
        lw $t1, 0($t0) # load the keystroke event into $t6

        # branch based on the keystroke
        beq $t1, 113, EXIT # branch to quit on 113 = 'q'
        beq $t1, 43, SPEED_UP # branch to speed up on 43 = '+'
        beq $t1, 45, SLOW_DOWN # branch to slow down on 45 = '-'
        beq $t1, 119, MOVE_FROG_UP # branch to up on 119 = 'w'
        beq $t1, 100, MOVE_FROG_RIGHT # branch to right on 100 = 'd'
        beq $t1, 115, MOVE_FROG_DOWN # branch to down on 115 = 's'
        beq $t1, 97, MOVE_FROG_LEFT # branch to down on 97 = 'a'

        jr $ra

MOVE_FROG_UP: # move frog up
        push_ra

        jal SFX_MOVE

        jal LOAD_POSITION_AND_STORE_PREVIOUS

        pop_ra

        li $t1, 0
        sh $t1, 2($t0) # write the new direction

        lbu $t1, 1($t0) # load previous y position
        addi $t1, $t1, -16 # adjust y position
        sb $t1, 1($t0) # save new y position

        # NOTE: we don't need to check for the minimum y position, because if the frog is in this range it will be detected as already having won

        jr $ra

MOVE_FROG_RIGHT: # move frog right
        push_ra

        jal SFX_MOVE

        jal LOAD_POSITION_AND_STORE_PREVIOUS

        pop_ra

        li $t1, 1
        sh $t1, 2($t0) # write the new direction

        lbu $t1, 0($t0) # load previous x position
        addi $t1, $t1, 16 # adjust x position
        sb $t1, 0($t0) # save new x position

        addi $t1, $t1, -113 # find difference between current and max x position
        bltz $t1, RETURN # early return if current is less than max

        li $t1, 112
        sb $t1, 0($t0) # otherwise, set the x position to max

        jr $ra

MOVE_FROG_DOWN: # move frog down
        push_ra

        jal SFX_MOVE

        jal LOAD_POSITION_AND_STORE_PREVIOUS

        pop_ra

        li $t1, 2
        sh $t1, 2($t0) # write the new direction

        lbu $t1, 1($t0) # load previous y position
        addi $t1, $t1, 16 # adjust y position
        sb $t1, 1($t0) # save new y position

        addi $t1, $t1, -113 # find difference between current and max y position
        bltz $t1, RETURN # early return if current is less than max

        li $t1, 112
        sb $t1, 1($t0) # otherwise, set the y position to max

        jr $ra

MOVE_FROG_LEFT: # move frog left
        push_ra

        jal SFX_MOVE

        jal LOAD_POSITION_AND_STORE_PREVIOUS

        pop_ra

        li $t1, 3
        sh $t1, 2($t0) # write the new direction

        lbu $t1, 0($t0) # load previous x position
        addi $t1, $t1, -16 # adjust x position
        sb $t1, 0($t0) # save new x position

        bgtz $t1, RETURN # early return if current is greater than 0

        sb $zero, 0($t0) # otherwise, set the x position to 0

        jr $ra

LOAD_POSITION_AND_STORE_PREVIOUS:
        la $t0, frogPosition # load frog position address
        lw $t1, 0($t0) # load frog position
        la $t2, previousFrogPosition # load previous frog position address
        sw $t1 0($t2) # save current position to previous

        jr $ra

MOVE_OBJS: # move the objects
        push_ra

        # move logs
        la $t0, logPositions # load the log positions' address

        # move the first log
        add $a0, $t0, $zero
        addi $a1, $t0, 1
        li $a2, 2
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        add $a2, $a2, $v0
        jal MOVE_OBJ

        # move the second log
        addi $a0, $t0, 1
        add $a1, $t0, $zero
        li $a2, 2
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        add $a2, $a2, $v0
        jal MOVE_OBJ

        # move the third log
        addi $a0, $t0, 2
        addi $a1, $t0, 3
        li $a2, -1
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        sub $a2, $a2, $v0
        jal MOVE_OBJ

        # move the fourth log
        addi $a0, $t0, 3
        addi $a1, $t0, 2
        li $a2, -1
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        sub $a2, $a2, $v0
        jal MOVE_OBJ

        # move cars
        la $t0, carPositions # load the car positions' address

        # move the first car
        add $a0, $t0, $zero
        addi $a1, $t0, 1
        li $a2, 2
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        add $a2, $a2, $v0
        jal MOVE_OBJ

        # move the second car
        addi $a0, $t0, 1
        add $a1, $t0, $zero
        li $a2, 2
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        add $a2, $a2, $v0
        jal MOVE_OBJ

        # move the third car
        addi $a0, $t0, 2
        addi $a1, $t0, 3
        li $a2, -1
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        sub $a2, $a2, $v0
        jal MOVE_OBJ

        # move the fourth car
        addi $a0, $t0, 3
        addi $a1, $t0, 2
        li $a2, -1
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        sub $a2, $a2, $v0
        jal MOVE_OBJ

        pop_ra

        jr $ra

MOVE_OBJ: # move a single object, where $a0 is the address of the object being moved, $a1 is the address of the other object in that row, and $a2 is the amount to move it by
        lbu $t1, 0($a0) # load the position of the current object

        # branch accordingly
        bltz $t1, MAYBE_START
        beq $t1, 0, MAYBE_START
        j SHIFT_OBJ

MAYBE_START:
        # back up the argument so we can use the random syscall
        add $t2, $a0, $zero

        # use random syscall
        li $v0, 42
        li $a0, 0
        li $a1, 16 # the maximum number
        syscall

        bne $a0, 0, RETURN # early return if the random number wasn't 0

        # check if it's shifted by a negative amount
        bltz $a2, START_FROM_END # if so, start from the other end

        # reset
        li $t1, 4
        sb $t1, 0($t2) # save the position

        jr $ra

START_FROM_END:
        # reset
        li $t1, 154
        sb $t1, 0($t2) # save the position

        jr $ra

SHIFT_OBJ:
        addu $t1, $t1, $a2 # increment the current object's position
        sb $t1, 0($a0) # save the new position of the current object

        addiu $t2, $t1, -154 # check difference between current position and max
        bgtz $t2, RESET_OBJ

        jr $ra

RESET_OBJ:
        sb $zero, 0($a0)

        jr $ra
# }}}
# collisions {{{
CHECK_COLLISIONS: # check all collisions
        push_ra

        la $t0, frogPosition # load the address containing the frog's position
        lbu $t1, 0($t0) # load the frog's x position
        lbu $t2, 1($t0) # load the frog's y position

        jal CHECK_CAR_COLLISIONS
        jal CHECK_LOG_COLLISIONS
        jal CHECK_FINISH_COLLISIONS

        pop_ra

        jr $ra

CHECK_OBJECT_COLLISION: # expects $a0 to store the position of the object from the right side of the screen, and expects $t1 to still have the frog's x position. $v0 will store the result of the check, 0 means collision, 1 means no collsion. operates on the assumption that the object is 8 pixels long
        # convert $a0 to distance from the left with offset for the next check
        li $t3, 112
        sub $t3, $t3, $a0

        li $v0, 0 # load 0 return value by default

        # check if the frog x is within 4 pixels of the object from the left side
        bge $t3, $t1, RETURN

        # check if the frog x is within 8 pixels of the object from the right side
        addi $t3, $t3, 48
        bge $t1, $t3, RETURN

        # if we still haven't returned, they must be touching, return 1
        li $v0, 1
        jr $ra

CHECK_CAR_COLLISIONS: # check whether the frog is touching any cars and react accordingly
        # early return if we're not in a car row
        beq $t2, 80, CHECK_CAR_ROW_1_COLLISIONS
        beq $t2, 96, CHECK_CAR_ROW_2_COLLISIONS

        jr $ra

CHECK_CAR_ROW_1_COLLISIONS:
        push_ra

        la $a0, carPositions
        lbu $a0, 0($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_CAR_COLLISION

        la $a0, carPositions
        lbu $a0, 1($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_CAR_COLLISION

        pop_ra

        jr $ra

CHECK_CAR_ROW_2_COLLISIONS:
        push_ra

        la $a0, carPositions
        lbu $a0, 2($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_CAR_COLLISION

        la $a0, carPositions
        lbu $a0, 3($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_CAR_COLLISION

        pop_ra

        jr $ra

HANDLE_CAR_COLLISION:
        jal SFX_CAR

        pop_ra

        j DEATH

CHECK_LOG_COLLISIONS: # check whether the frog is touching any logs and react accordingly
        # early return if we're not in a log row
        beq $t2, 32, CHECK_LOG_ROW_1_COLLISIONS
        beq $t2, 48, CHECK_LOG_ROW_2_COLLISIONS

        jr $ra

CHECK_LOG_ROW_1_COLLISIONS:
        push_ra

        la $a0, logPositions
        lbu $a0, 0($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_ROW_ONE_LOG_COLLISION

        la $a0, logPositions
        lbu $a0, 1($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_ROW_ONE_LOG_COLLISION

        pop_ra

        # if we're not touching either log, we're in the water
        j DEATH

CHECK_LOG_ROW_2_COLLISIONS:
        push_ra

        la $a0, logPositions
        lbu $a0, 2($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_ROW_TWO_LOG_COLLISION

        la $a0, logPositions
        lbu $a0, 3($a0)
        jal CHECK_OBJECT_COLLISION

        beq $v0, 1, HANDLE_ROW_TWO_LOG_COLLISION

        pop_ra

        # if we're not touching either log, we're in the water
        j WATER_DEATH

HANDLE_ROW_ONE_LOG_COLLISION:
        li $t0, 2
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        add $t0, $t0, $v0

        lb $t1, frogPosition # load the previous frog x position
        sub $t1, $t1, $t0 # shift position
        sb $t1, frogPosition # save new position

        bltz $t1, WATER_DEATH # if the position is off the screen, this is a death

        j RETURN_WITH_STACKPOP

HANDLE_ROW_TWO_LOG_COLLISION:
        li $t0, -1
        jal GET_NUM_SAFE # load the number of safe frogs into $v0 
        sub $t0, $t0, $v0

        lb $t1, frogPosition # load the previous frog x position
        sub $t1, $t1, $t0 # shift position

        sb $t1, frogPosition # save new position

        # if the position is off the screen, this is a death
        bgt $t1, 112, WATER_DEATH

        j RETURN_WITH_STACKPOP

WATER_DEATH:
        jal SFX_SINK

        j DEATH

CHECK_FINISH_COLLISIONS: # check whether the frog is touching any logs and react accordingly
        # early return if we're not on the finish row
        bne $t2, 16, RETURN

        # load frog x position
        la $t0, frogPosition
        lb $t0, 0($t0)

        # check whether frog is close enough to the first region
        addi $t1, $t0, -5
        bltz $t1, HANDLE_REGION_ONE_COLLISION

        # check whether frog is close enough to the second region
        addi $t1, $t0, -27
        bltz $t1, SKIP_OTHER_REGION_TWO_CHECK
        addi $t1, $t0, -53
        bltz $t1, HANDLE_REGION_TWO_COLLISION
SKIP_OTHER_REGION_TWO_CHECK:

        # check whether frog is close enough to the third region
        addi $t1, $t0, -59
        bltz $t1, SKIP_OTHER_REGION_THREE_CHECK
        addi $t1, $t0, -85
        bltz $t1, HANDLE_REGION_THREE_COLLISION
SKIP_OTHER_REGION_THREE_CHECK:

        # check whether frog is close enough to the four region
        addi $t1, $t0, -91
        bltz $t1, SKIP_OTHER_REGION_FOUR_CHECK
        addi $t1, $t0, -117
        bltz $t1, HANDLE_REGION_FOUR_COLLISION
SKIP_OTHER_REGION_FOUR_CHECK:

        # if we're in the finish row but not close enough to any region, we're dead
        push_ra

        jal SFX_SINK

        pop_ra

        j DEATH

HANDLE_REGION_ONE_COLLISION:
        li $a0, 0
        jal HANDLE_GIVEN_REGION_COLLISION

        jr $ra

HANDLE_REGION_TWO_COLLISION:
        li $a0, 1
        jal HANDLE_GIVEN_REGION_COLLISION

        jr $ra

HANDLE_REGION_THREE_COLLISION:
        li $a0, 2
        jal HANDLE_GIVEN_REGION_COLLISION

        jr $ra

HANDLE_REGION_FOUR_COLLISION:
        li $a0, 3
        jal HANDLE_GIVEN_REGION_COLLISION

        jr $ra
# }}}
# drawing {{{
INITIAL_DRAW: # draw some of the things that only need to be draw once
        push_ra

        # draw hearts
        jal DRAW_HEARTS

        # draw second end rows
        jal DRAW_SECOND_ENDING_ROW

        # draw ending regions
        jal DRAW_END_REGIONS_AND_SCORE

        # drawing the middle safe zone
        lw $t0, displayAddress # load display address into $t0
        lw $a0, grassColour # $a0 will store the current colour to write
        addi $a1, $t0, 2048
        addi $a2, $a1, 512
        jal DRAW_LINE

        # drawing the starting safe zone
        lw $t0, displayAddress # load display address into $t0
        lw $a0, grassColour # $a0 will store the current colour to write
        addi $a1, $t0, 3584
        addi $a2, $a1, 512
        jal DRAW_LINE

        # draw frog
        jal DRAW_FROG

        pop_ra

        jr $ra

DRAW: # write the scene's colours to the correct spots in memory
        push_ra

        # draw objects
        jal DRAW_OBJS

        # redraw the background for the frog's previous position
        jal REDRAW_FROG_BACKGROUND

        # draw frog
        jal DRAW_FROG

        pop_ra

        jr $ra

DRAW_OBJS:
        push_ra

        # drawing first section of water

        lw $t0, displayAddress # load display address into $t0
        addi $t0, $t0, 1024 # adjust $t0 to the first pixel of water
        addi $t1, $t0, 128 # set the last position to write to
        lw $t2, waterColour # load water colour
        lw $t3, logColour # load log colour

        la $a3, logPositions # load log positions
        jal START_DRAWING_BACKGROUND_PIXELS

        # duplicate to second row
        addi $a0, $t0, -128
        add $a1, $t1, $zero
        jal DUPLICATE_ROW

        # duplicate to third row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW

        # duplicate to fourth row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW

        # drawing second section of water

        lw $t0, displayAddress # load display address into $t0
        addi $t0, $t0, 1536 # adjust $t0 to the first pixel of water
        addi $t1, $t0, 128 # set the last position to write to

        addi $a3, $a3, 2 # shift log position address
        jal START_DRAWING_BACKGROUND_PIXELS

        # duplicate to second row
        addi $a0, $t0, -128
        add $a1, $t1, $zero
        jal DUPLICATE_ROW

        # duplicate to third row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW

        # duplicate to fourth row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW

        # drawing first section of road

        lw $t0, displayAddress # load display address into $t0
        addi $t0, $t0, 2560 # adjust $t0 to the first pixel of road
        addi $t1, $t0, 128 # set the last position to write to
        lw $t2, roadColour # load road colour
        lw $t3, carColour # load car colour

        la $a3, carPositions # load car positions
        jal START_DRAWING_BACKGROUND_PIXELS

        # duplicate to second row
        addi $a0, $t0, -128
        add $a1, $t1, $zero
        jal DUPLICATE_ROW

        # duplicate to third row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW

        # duplicate to fourth row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW

        # drawing second section of road

        lw $t0, displayAddress # load display address into $t0
        addi $t0, $t0, 3072 # adjust $t0 to the first pixel of road
        addi $t1, $t0, 128 # set the last position to write to

        addi $a3, $a3, 2 # shift car position address
        jal START_DRAWING_BACKGROUND_PIXELS

        # duplicate to second row
        addi $a0, $t0, -128
        add $a1, $t1, $zero
        jal DUPLICATE_ROW

        # duplicate to third row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW

        # duplicate to fourth row
        add $a0, $a0, 128
        addi $a1, $a1, 128
        jal DUPLICATE_ROW


        pop_ra

        jr $ra

DUPLICATE_ROW: # expects $a0 to hold the start address of the first row and $a1 to hold the start address of the second row
        # NOTE: this is done without any looping cause it's just way more performant. I tried doing it by looping and it was slow because the check comparisons have too much of a performance impact
        lw $t7, 0($a0) # load from current first row
        sw $t7, 0($a1) # save to current second row
        lw $t7, 4($a0)
        sw $t7, 4($a1)
        lw $t7, 8($a0)
        sw $t7, 8($a1)
        lw $t7, 12($a0)
        sw $t7, 12($a1)
        lw $t7, 16($a0)
        sw $t7, 16($a1)
        lw $t7, 20($a0)
        sw $t7, 20($a1)
        lw $t7, 24($a0)
        sw $t7, 24($a1)
        lw $t7, 28($a0)
        sw $t7, 28($a1)
        lw $t7, 32($a0)
        sw $t7, 32($a1)
        lw $t7, 36($a0)
        sw $t7, 36($a1)
        lw $t7, 40($a0)
        sw $t7, 40($a1)
        lw $t7, 44($a0)
        sw $t7, 44($a1)
        lw $t7, 48($a0)
        sw $t7, 48($a1)
        lw $t7, 52($a0)
        sw $t7, 52($a1)
        lw $t7, 56($a0)
        sw $t7, 56($a1)
        lw $t7, 60($a0)
        sw $t7, 60($a1)
        lw $t7, 64($a0)
        sw $t7, 64($a1)
        lw $t7, 68($a0)
        sw $t7, 68($a1)
        lw $t7, 72($a0)
        sw $t7, 72($a1)
        lw $t7, 76($a0)
        sw $t7, 76($a1)
        lw $t7, 80($a0)
        sw $t7, 80($a1)
        lw $t7, 84($a0)
        sw $t7, 84($a1)
        lw $t7, 88($a0)
        sw $t7, 88($a1)
        lw $t7, 92($a0)
        sw $t7, 92($a1)
        lw $t7, 96($a0)
        sw $t7, 96($a1)
        lw $t7, 100($a0)
        sw $t7, 100($a1)
        lw $t7, 104($a0)
        sw $t7, 104($a1)
        lw $t7, 108($a0)
        sw $t7, 108($a1)
        lw $t7, 112($a0)
        sw $t7, 112($a1)
        lw $t7, 116($a0)
        sw $t7, 116($a1)
        lw $t7, 120($a0)
        sw $t7, 120($a1)
        lw $t7, 124($a0)
        sw $t7, 124($a1)

        jr $ra

START_DRAWING_BACKGROUND_PIXELS:
        push_ra

        # check first object position
        lbu $t4, 0($a3)

        sub $t5 $t1, $t4 # calculate first object start from end of line
        drop_bits $t5, 2 # drop the lower 2 bits of $t5

        # draw line if we're at or past that index
        bge $t0, $t5, DRAW_STARTING_LINE

        # check second object position
        lbu $t4, 1($a3)

        sub $t5 $t1, $t4 # calculate second object start from end of line
        drop_bits $t5, 2 # drop the lower 2 bits of $t5

        # draw line if we're at or past that index
        bge $t0, $t5, DRAW_STARTING_LINE

        j DRAW_BACKGROUND_PIXELS # otherwise, continue 

DRAW_STARTING_LINE:
        add $a0, $t3, $zero # load object colour

        add $a1, $t0, $zero # set current value to start of line
        addi $a2, $t5, 32 # set last value to end of object

        jal DRAW_LINE

        add $t0, $a1, $zero # update current

        # fall through cause we don't need to check if the second object is from the start since they should be separated

DRAW_BACKGROUND_PIXELS:
        # check first object position
        lb $t4, 0($a3)

        sub $t5 $t1, $t4 # calculate first object start from end of line
        drop_bits $t5, 2 # drop the lower 2 bits of $t5

        beq $t5, $t0, DRAW_OBJECT_LINE # draw line if we're currently at that index

        # check second object position
        lb $t4, 1($a3)

        sub $t5 $t1, $t4 # calculate second object start from end of line
        drop_bits $t5, 2 # drop the lower 2 bits of $t5

        beq $t5, $t0, DRAW_OBJECT_LINE # draw line if we're currently at that index

        beq $t0, $t1, RETURN_WITH_STACKPOP # return if the current is the last

        sw $t2, 0($t0) # write background colour
        addi $t0, $t0, 4 # increment current

        j DRAW_BACKGROUND_PIXELS

DRAW_OBJECT_LINE:
        add $a0, $t3, $zero # load object colour

        add $a1, $t5, $zero # set current value
        beq $t1, $a1, RETURN_WITH_STACKPOP # return if the current value is the end
        addi $a2, $t5, 32 # set finish drawing to end of

        bgt $t1, $a2, DONT_FIX_END # skip the next instrutions
        add $a2, $t1, $zero # set the end address to the end of the line if we didn't jump
DONT_FIX_END:
        jal DRAW_LINE # draw the line

        add $t0, $a1, $zero # update current

        j DRAW_BACKGROUND_PIXELS

REDRAW_FROG_BACKGROUND:
        lw $t0, displayAddress # load display address into $t0
        lw $t1, grassColour # load the grass colour into $t1
        la $t2, previousFrogPosition # load the address containing the frog's previous position
        lbu $t4, 1($t2) # load the frog's y position

        # early return if the frog was in a row with objects
        beq $t4, 0, RETURN
        beq $t4, 16, RETURN
        beq $t4, 32, RETURN
        beq $t4, 48, RETURN
        beq $t4, 80, RETURN
        beq $t4, 96, RETURN

        sll $t4, $t4, 5 # multiply the y position by 128
        add $t0, $t0, $t4 # save the frog y position plus the display address to $t0
        lbu $t4, 0($t2) # load the frog's x position
        add $t0, $t0, $t4 # save the frog x position plus the y and display address to $t0
        drop_bits $t0, 2 # drop the lower 2 bits of $t0

        sw $t1, 0($t0)
        sw $t1, 4($t0)
        sw $t1, 8($t0)
        sw $t1, 12($t0)
        sw $t1, 128($t0)
        sw $t1, 132($t0)
        sw $t1, 136($t0)
        sw $t1, 140($t0)
        sw $t1, 256($t0)
        sw $t1, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 268($t0)
        sw $t1, 384($t0)
        sw $t1, 388($t0)
        sw $t1, 392($t0)
        sw $t1, 396($t0)

        jr $ra

DRAW_FROG_IF_ROW: # draw the frog if it is in the same row named in $a3
        la $t2, frogPosition # load the address containing the frog's position
        lbu $t5, 1($t2) # load the frog's y position
        sll $a3, $a3, 4 # multiply row

        bne $t5, $a3, RETURN # check if the positions aren't equal

        j DRAW_FROG # if not, draw the frog

DRAW_FROG: # draw the frog
        lw $t0, displayAddress # load display address into $t0
        lw $t1, frogColour # save the frog colour to $t1
        la $t2, frogPosition # load the address containing the frog's position
        lh $t3, 2($t2) # load the frog's direction
        lbu $t4, 1($t2) # load the frog's y position
        sll $t4, $t4, 5 # multiply the y position by 128
        add $t0, $t0, $t4 # save the frog y position plus the display address to $t0
        lbu $t4, 0($t2) # load the frog's x position
        add $t0, $t0, $t4 # save the frog x position plus the y and display address to $t0
        drop_bits $t0, 2 # drop the lower 2 bits of $t0

        # jump to the drawing function corresponding to the current rotation
        beq $t3, 0, DRAW_FROG_FORWARD
        beq $t3, 1, DRAW_FROG_RIGHT
        beq $t3, 2, DRAW_FROG_DOWN
        beq $t3, 3, DRAW_FROG_LEFT

DRAW_FROG_FORWARD:
        sw $t1, 0($t0)
        sw $t1, 12($t0)
        sw $t1, 128($t0)
        sw $t1, 132($t0)
        sw $t1, 136($t0)
        sw $t1, 140($t0)
        sw $t1, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 384($t0)
        sw $t1, 396($t0)

        jr $ra

DRAW_FROG_RIGHT:
        sw $t1, 0($t0)
        sw $t1, 8($t0)
        sw $t1, 12($t0)
        sw $t1, 132($t0)
        sw $t1, 136($t0)
        sw $t1, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 384($t0)
        sw $t1, 392($t0)
        sw $t1, 396($t0)

        jr $ra

DRAW_FROG_DOWN:
        sw $t1, 0($t0)
        sw $t1, 12($t0)
        sw $t1, 132($t0)
        sw $t1, 136($t0)
        sw $t1, 256($t0)
        sw $t1, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 268($t0)
        sw $t1, 384($t0)
        sw $t1, 396($t0)

        jr $ra

DRAW_FROG_LEFT:
        sw $t1, 0($t0)
        sw $t1, 4($t0)
        sw $t1, 12($t0)
        sw $t1, 132($t0)
        sw $t1, 136($t0)
        sw $t1, 260($t0)
        sw $t1, 264($t0)
        sw $t1, 384($t0)
        sw $t1, 388($t0)
        sw $t1, 396($t0)

        jr $ra

DRAW_END_REGIONS_AND_SCORE:
        push_ra

        jal DRAW_SCORE

        lw $t0, displayAddress # load display address to $t0

        # draw the first end region
        addi $t0, $t0, 512 # increment display address to the position of the first end region
        la $a0, endRegions
        jal DRAW_END_REGION

        # draw the second end region
        addi $t0, $t0, 32
        addi $a0, $a0, 1
        jal DRAW_END_REGION

        # draw the third end region
        addi $t0, $t0, 32
        addi $a0, $a0, 1
        jal DRAW_END_REGION

        # draw the fourth end region
        addi $t0, $t0, 32
        addi $a0, $a0, 1
        jal DRAW_END_REGION

        j RETURN_WITH_STACKPOP 

DRAW_SCORE:
        push_ra

        jal GET_NUM_SAFE

        pop_ra

        lw $a0, displayAddress # load display address into $t0
        addi $a0, $a0, 112 # shift address to starting score address
        lw $a1, rocksColour

        beq $v0, 0, DRAW_ZERO_SCORE
        beq $v0, 1, DRAW_ONE_SCORE
        beq $v0, 2, DRAW_TWO_SCORE
        beq $v0, 3, DRAW_THREE_SCORE
        beq $v0, 4, DRAW_FOUR_SCORE

        j RETURN_WITH_STACKPOP

DRAW_ZERO_SCORE:
        sw $zero 0($a0)
        sw $zero 4($a0)
        sw $zero 8($a0)
        sw $a1 12($a0)
        sw $zero 128($a0)
        sw $a1 132($a0)
        sw $zero 136($a0)
        sw $a1 140($a0)
        sw $zero 256($a0)
        sw $a1 260($a0)
        sw $zero 264($a0)
        sw $a1 268($a0)
        sw $zero 384($a0)
        sw $zero 388($a0)
        sw $zero 392($a0)
        sw $a1 396($a0)
        sw $a1 516($a0)

        j RETURN

DRAW_ONE_SCORE:
        sw $a1 0($a0)
        sw $a1 4($a0)
        sw $zero 8($a0)
        sw $a1 12($a0)
        sw $a1 128($a0)
        sw $zero 132($a0)
        sw $zero 136($a0)
        sw $a1 140($a0)
        sw $a1 256($a0)
        sw $a1 260($a0)
        sw $zero 264($a0)
        sw $a1 268($a0)
        sw $a1 384($a0)
        sw $a1 388($a0)
        sw $zero 392($a0)
        sw $a1 396($a0)
        sw $a1 516($a0)

        j RETURN

DRAW_TWO_SCORE:
        sw $a1 0($a0)
        sw $zero 4($a0)
        sw $zero 8($a0)
        sw $a1 12($a0)
        sw $a1 128($a0)
        sw $a1 132($a0)
        sw $zero 136($a0)
        sw $a1 140($a0)
        sw $a1 256($a0)
        sw $zero 260($a0)
        sw $a1 264($a0)
        sw $a1 268($a0)
        sw $a1 384($a0)
        sw $zero 388($a0)
        sw $zero 392($a0)
        sw $a1 396($a0)
        sw $a1 516($a0)

        j RETURN

DRAW_THREE_SCORE:
        sw $a1 0($a0)
        sw $zero 4($a0)
        sw $a1 8($a0)
        sw $a1 12($a0)
        sw $a1 128($a0)
        sw $a1 132($a0)
        sw $zero 136($a0)
        sw $a1 140($a0)
        sw $a1 256($a0)
        sw $zero 260($a0)
        sw $a1 264($a0)
        sw $a1 268($a0)
        sw $a1 384($a0)
        sw $a1 388($a0)
        sw $zero 392($a0)
        sw $a1 396($a0)
        sw $zero 516($a0)

        j RETURN

DRAW_FOUR_SCORE:
        sw $zero 0($a0)
        sw $a1 4($a0)
        sw $zero 8($a0)
        sw $a1 12($a0)
        sw $zero 128($a0)
        sw $a1 132($a0)
        sw $zero 136($a0)
        sw $a1 140($a0)
        sw $zero 256($a0)
        sw $zero 260($a0)
        sw $zero 264($a0)
        sw $a1 268($a0)
        sw $a1 384($a0)
        sw $a1 388($a0)
        sw $zero 392($a0)
        sw $a1 396($a0)
        sw $a1 516($a0)

        j RETURN

DRAW_END_REGION: # $t0 should store the first pixel of the region, and $a0 should store the memory address indicating whether or not the end region is filled
        push_ra

        # draw grass
        lw $t2, grassColour
        sw $t2, 0($t0)
        sw $t2, 4($t0)
        sw $t2, 8($t0)
        sw $t2, 12($t0)
        sw $t2, 128($t0)
        sw $t2, 132($t0)
        sw $t2, 136($t0)
        sw $t2, 140($t0)
        sw $t2, 256($t0)
        sw $t2, 260($t0)
        sw $t2, 264($t0)
        sw $t2, 268($t0)
        sw $t2, 384($t0)
        sw $t2, 388($t0)
        sw $t2, 392($t0)
        sw $t2, 396($t0)

        lb $t1, 0($a0) # load whether the region is filled

        # early return if the region is not filled
        beq $t1, 0, RETURN_WITH_STACKPOP

        # draw the frog in the square
        lw $t1, frogColour # save the frog colour to $t1
        jal DRAW_FROG_DOWN

        j RETURN_WITH_STACKPOP

DRAW_FIRST_ENDING_ROW: # drawing first ending row
        push_ra

        lw $t0, displayAddress # load display address into $t0
        lw $a0, rocksColour # $a0 will store the current colour to write
        add $a1, $t0, $zero # $a1 will store the current memory address to write to
        addi $a2, $a1, 512 # $a2 will store the last memory address to write to
        jal DRAW_LINE

        j RETURN_WITH_STACKPOP

DRAW_SECOND_ENDING_ROW: # drawing second ending row
        push_ra

        lw $t0, displayAddress # load display address into $t0
        lw $a0, rocksColour # $a0 will store the current colour to write
        addi $a1, $t0, 512 # $a1 will store the current memory address to write to
        addi $a2, $a1, 512 # $a2 will store the last memory address to write to
        jal DRAW_LINE

        j RETURN_WITH_STACKPOP

DRAW_HEARTS: # draw the lives
        push_ra

        jal DRAW_FIRST_ENDING_ROW

        jal DRAW_SCORE

        lw $a0, displayAddress # load display address
        lb $t0, lives # load current number of lives
        beq $t0, 0, RETURN_WITH_STACKPOP # return if there are no lives left (used for the final draw before game over)

        # draw first heart
        addi $a0, $a0, 16
        jal DRAW_HEART

        lb $t0, lives # load current number of lives
        beq $t0, 1, RETURN_WITH_STACKPOP # return if there is only one life left

        # draw second heart
        addi $a0, $a0, 32
        jal DRAW_HEART

        lb $t0, lives # load current number of lives
        beq $t0, 2, RETURN_WITH_STACKPOP # return if there are two lives left

        # draw third heart
        addi $a0, $a0, 32
        jal DRAW_HEART

        j RETURN_WITH_STACKPOP

DRAW_HEART: # $a0 should store the first pixel of the region
        lw $t0, heartColour
        sw $t0, 0($a0)
        sw $t0, 12($a0)
        sw $t0, 128($a0)
        sw $t0, 132($a0)
        sw $t0, 136($a0)
        sw $t0, 140($a0)
        sw $t0, 256($a0)
        sw $t0, 260($a0)
        sw $t0, 264($a0)
        sw $t0, 268($a0)
        sw $t0, 388($a0)
        sw $t0, 392($a0)

        jr $ra

DRAW_LINE: # expects $a0 to store colour, $a1 to store the current memory address to write to, and $a2 to store the last address to write to
        sw $a0, 0($a1) # load the colour into the current address to write to
        addi $a1, $a1, 4 # increment the current address

        # return if the current write address is greater than or equal to the last
        ble $a2, $a1, RETURN

        j DRAW_LINE # continue looping
# }}}
# sleep {{{
SLEEP: # pause for the time between ticks
        li $v0, 32 # load 32 into $v0, the code to signal we want to use the sleep syscall
        lbu $a0, tickDelay # sleep for the tick delay
        syscall # sleep
        jr $ra # return
# }}}
# sfx {{{
SFX_MOVE:
        li $v0, 31
        li $a0, 62
        li $a1, 167
        li $a2, 34
        li $a3, 41
        syscall

        j RETURN

SFX_CAR:
        li $v0, 31
        li $a0, 61
        li $a1, -1
        li $a2, 65
        li $a3, 63
        syscall

        j RETURN

SFX_SINK:
        li $v0, 31
        li $a0, 55
        li $a1, -1
        li $a2, 108
        li $a3, 63
        syscall

        j RETURN

SFX_SCORE:
        li $v0, 31
        li $a0, 60
        li $a1, -1
        li $a2, 104
        li $a3, 63
        syscall

        j RETURN

SFX_WIN:
        li $v0, 33
        li $a0, 60
        li $a1, -1
        li $a2, 123
        li $a3, 63
        syscall

        j RETURN

SFX_LOOSE:
        li $v0, 33
        li $a0, 40
        li $a1, -1
        li $a2, 98
        li $a3, 63
        syscall

        j RETURN
# }}}
# helpers {{{
RETURN: # useful for returning from beq
        jr $ra # return

RETURN_WITH_STACKPOP: # useful for returning from beq
        pop_ra

        jr $ra # return

SPEED_UP: # decrease tick delay, useful for testing
        lbu $t0, tickDelay
        addi $t0, $t0, -1
        sb $t0, tickDelay

        jr $ra

SLOW_DOWN: # increase tick delay, useful for testing
        lbu $t0, tickDelay
        addi $t0, $t0, 1
        sb $t0, tickDelay

        jr $ra

HANDLE_GIVEN_REGION_COLLISION: # $a0 should store the number of the region to access
        la $t0, endRegions # load end region address
        add $t0, $t0, $a0 # add number of region to the address
        lb $t1, 0($t0) # load the previous value
        beq $t1, 1, DEATH # if the region is already filled, this counts as a death
        li $t1, 1
        sb $t1, 0($t0) # save the new value
        jal CHECK_WIN_CONDITION # check if the user has won
        jal DRAW_END_REGIONS_AND_SCORE # redraw end regions

        push_ra

        jal SFX_SCORE

        pop_ra

        j RESET # reset

GET_NUM_SAFE: # put the number of save frogs in $v0
        la $t7, endRegions # load end regions 
        lb $v0, 0($t7) # load first region
        lb $t1, 1($t7) # load second region
        add $v0, $v0, $t1 # add second to sum
        lb $t1, 2($t7) # load third region
        add $v0, $v0, $t1 # add third to sum
        lb $t1, 3($t7) # load fourth region
        add $v0, $v0, $t1 # add fourth to sum

        jr $ra

CHECK_WIN_CONDITION: # check if the game is over
        lw $t0, endRegions # load end regions

        beq $t0, 0x01010101, WIN # exit if the ends are all filled

        jr $ra

DEATH: # handle a death
        la $t0, lives
        lb $t1, 0($t0)
        addi $t1, $t1, -1 # subtract from lives

        sb $t1, 0($t0) # save lives

        push_ra

        jal DRAW_HEARTS

        pop_ra

        # exit if there are 0 lives left
        la $t0, lives
        lb $t1, 0($t0)
        beq $t1, 0, GAME_OVER

        # fall through to next label

RESET: # reset used in the case of death or success
        # reset frog position
        la $t0, frogPosition
        li $t1, 0x00007038
        sw $t1, 0($t0)

        jal SLEEP

        j LOOP

WIN:
        jal DRAW
        jal DRAW_SCORE
        jal SFX_WIN

        j EXIT

GAME_OVER:
        jal DRAW
        jal SFX_LOOSE

        # for now, fall through and exit

EXIT:
        li $v0, 10 # terminate the program gracefully
        syscall
# }}}
