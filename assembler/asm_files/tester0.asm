// Purpose of this assembly file is to test every instruction in vanilla core.
// In each test a counter is increased and if the test is passed, it is written
// to place 0xC0FFEEEE in the data memory, otherwise it will be written in the
// 0xDEADDEAD location and the wrong calculated value will be written in 0xC0DEC0DE
// Location, which these location accesses will cause the testbench to stop.

// There is a function which gets the test number, the calculated value and the
// desired value, and implements the mentioned work. However, before calling this
// subroutine, the instructions which are used within it are tested separately.
// First of all a BEQ in forward and backward direction, then the mov instruction,
// ADDU, SUBU and JALR are tested in order. IF all of them are passed, the subroutine
// can be called, and rest of the instructions are tested using this subroutine. 

// It is assumed that SW instruction is correct, otherwise there would not be any 
// writes at all which can be detected in the test bench.

.data
LW_Test:
.word 0xAAAA5555
LBU_TEST:
.word 0x00000000

.kernel tester

// Constant values of 1 and 6 which are required during the program
.const %ONE      , 1
.const %FOUR     , 4

.text

// Test for BEQ
BEQZ  $R0,START
NOP

// Check_answer subroutine

// Preconditions: $R5 = test number, $R6 = good answer, 
//                $R7 = actual answer, $R1 = return address
// Postconditions: $R7 is contaminated. 
//                 If the actual answer is correct, the test number will be 
//                 stored in the data memory pointed by $R10. IF it is wrong,
//                 the computed value and test number will be stored in the 
//                 data memory pointed by $R11 and $R12, respectively. Moreover,
//                 $R11 and $R12 are increased by one for future error occurance. 
// Invariants: test number and good answer is still valid.

// Address of the subroutine
.const %CHECK    , CHECK_ANSWER

CHECK_ANSWER:

SUBU  $R7,$R6
NOP
BEQZ  $R7,PASS
NOP

ADDU  $R7, $R6     // Reconstruct wrong answer
NOP
SW    $R11, $R7    // Output wrong answer
NOP
SW    $R12, $R5    // Indicate failed test
NOP
ADDU  $R11, %ONE
NOP
ADDU  $R12, %ONE
NOP
JALR  $R0,$R1
NOP

PASS:

SW    $R10, $R5    // indicate passed test
NOP
JALR  $R0,$R1
NOP

// Backward jump test
START0:
BEQZ  $R0,START1
NOP

// Start of the test
START:
BEQZ  $R0,START0
NOP

START1:

// Test for MOV
MOV   $R5,%ONE
NOP
.const %CODE_Test,  0xC0DEC0DE
.const %FAIL_Test,  0xDEADDEAD
.const %PASS_Test,  0xC0FFEEEE
.const %DONE_Test,  0x600DBEEF
MOV   $R10,%PASS_Test
NOP
MOV   $R11,%CODE_Test
NOP
MOV   $R12,%FAIL_Test
NOP
MOV   $R13,%DONE_Test
NOP

BEQZ  $R5, WRONG1
NOP
SW    $R10,$R5   // indicate passed test
NOP
BEQZ  $R0, CONT0
NOP

WRONG1:
SW    $R11,$R5  // Output wrong answer
NOP
SW    $R12,$R5  // Indicate failed test
NOP

CONT0:
// Test for ADDU
.constreg $C5, 0x11111111
.constreg $C6, 0xEEEEEEEF
ADDU  $R5,%ONE      // Update test counter 
NOP
MOV   $R7,$C5
NOP
ADDU  $R7,$C6
NOP
BEQZ  $R7,CONT1
NOP
SW    $R11,$R5   // Output wrong answer
NOP
SW    $R12,$R5   // Indicate failed test
NOP

CONT1:
SW    $R10,$R5   // Indicate passed test
NOP

// Test for SUBU
ADDU  $R5,%ONE      // Update test counter 
NOP
MOV   $R7,$R0
NOP
SUBU  $R7,%ONE
NOP
ADDU  $R7,%ONE
NOP
BEQZ  $R7,CONT2
NOP
SW    $R11,$R5   // Output wrong answer
NOP
SW    $R12,$R5   // Indicate failed test
NOP

CONT2:
SW    $R10,$R5   // Indicate passed test
NOP
// Test for ADDU and SUBU
ADDU  $R5,%ONE      // Update test counter 
NOP
MOV   $R7,$R0
NOP
SUBU  $R7,%ONE
NOP
ADDU  $R7,%ONE
NOP
BEQZ  $R7,CONT3
NOP
SW    $R11,$R5   // Output wrong answer
NOP
SW    $R12,$R5   // Indicate failed test
NOP

CONT3:
SW    $R10,$R5   // Indicate passed test
NOP

// Test for JALR
ADDU  $R5,%ONE
NOP
.const %NEXT     , NEXT
JALR  $R1,%NEXT
NOP
SW    $R12, $R5    // Indicate failed test
NOP

NEXT:
//Change the return address to the PASSED_JALR line.
ADDU  $R1,%FOUR    
NOP
JALR  $R0,$R1
NOP
SW    $R12, $R5    // Indicate failed test
NOP

PASSED_JALR:
SW    $R10, $R5    // indicate passed test
NOP

// Test for LBU
ADDU  $R5,%ONE
NOP
.constreg $C1, 0xAAAA5555
.constreg $C2, 0x000000AA
.const %LBU_TEST, LBU_TEST
MOV   $R8,%LBU_TEST
NOP
SW    $R8,$C1
NOP
ADDU  $R8,%ONE
NOP
ADDU  $R8,%ONE
NOP
LBU   $R7,$R8
NOP
MOV   $R6,$C2
NOP

// Call the checker subroutine, $R5 = test number, 
// $R6 = good answer, $R7 = actual answer, $R1 = return address
JALR  $R1,%CHECK
NOP

// Test for LW
ADDU  $R5,%ONE
NOP
.const %LW_Test, LW_Test, 3
MOV   $R7,$R0
NOP
LW    $R7,$C3
NOP
MOV   $R6,$C1
NOP
JALR  $R1,%CHECK
NOP

// Test for SB
ADDU  $R5,%ONE
NOP
.constreg $C4,0xAA005555
MOV   $R8,%LBU_TEST
NOP
ADDU  $R8,%ONE
NOP
ADDU  $R8,%ONE
NOP
SB    $R8,$R0
NOP
MOV   $R7,$R0
NOP
LW    $R7,%LBU_TEST
NOP
MOV   $R6,$C4
NOP
JALR  $R1,%CHECK
NOP

// Test for BNEQZ
ADDU  $R5,%ONE
NOP
MOV   $R2,$R0
NOP
ADDU  $R2,%ONE
NOP
BNEQZ $R2,CONT4
NOP
SW    $R12,$R5   // Indicate failed test
NOP
BEQZ  $R0, CONT5
NOP
CONT4:
SW    $R10,$R5  //Indicate Passed Test
NOP
CONT5:

// Test for BLTZ
ADDU  $R5,%ONE
NOP
MOV   $R2,$R0
NOP
SUBU  $R2,%ONE
NOP
BLTZ  $R2,CONT6
NOP
SW    $R12,$R5   // Indicate failed test
NOP
NOP
BEQZ  $R0, CONT7
NOP
CONT6:
SW    $R10,$R5  //Indicate Passed Test
NOP
CONT7:

// Test for BGTZ
ADDU  $R5,%ONE
NOP
MOV   $R2,$R0
NOP
ADDU  $R2,%ONE
NOP
BGTZ  $R2,CONT8
NOP
SW    $R12,$R5   // Indicate failed test
NOP
BEQZ  $R0, CONT9
NOP
CONT8:
SW    $R10,$R5  //Indicate Passed Test
NOP
CONT9:

// Test for SLT
ADDU  $R5,%ONE
NOP
MOV   $R7,$R0
NOP
SUBU  $R7,%ONE
NOP
SLT   $R7,$R0
NOP
MOV   $R6,%ONE
NOP
JALR  $R1,%CHECK
NOP

// Test for SLTU
ADDU  $R5,%ONE
NOP
MOV   $R7,$R0
NOP
SUBU  $R7,%ONE
NOP
SLTU  $R7,$R0
NOP
MOV   $R6,$R0
NOP
JALR  $R1,%CHECK
NOP

// Test for AND
.const %LOGIC1   , 0x0000FFFF
.const %LOGIC2   , 0x00FF00FF
.const %AND_ANS  , 0x000000FF
ADDU  $R5,%ONE
NOP
MOV   $R7,%LOGIC1
NOP
MOV   $R2,%LOGIC2
NOP
AND   $R7,$R2
NOP
MOV   $R6,%AND_ANS
NOP
JALR  $R1,%CHECK
NOP

// Test for OR
.const %OR_ANS   , 0x00FFFFFF
ADDU  $R5,%ONE
NOP
MOV   $R7,%LOGIC1
NOP
MOV   $R2,%LOGIC2
NOP
OR    $R7,$R2
NOP
MOV   $R6,%OR_ANS
NOP
JALR  $R1,%CHECK
NOP

// Test for NOR
.const %NOR_ANS  , 0xFF000000
ADDU  $R5,%ONE
NOP
MOV   $R7,%LOGIC1
NOP
MOV   $R2,%LOGIC2
NOP
NOR   $R7,$R2
NOP
MOV   $R6,%NOR_ANS
NOP
JALR  $R1,%CHECK
NOP

// Test for SLLV
.const %SHIFT_INP, 0x80000000
ADDU  $R5,%ONE
NOP
MOV   $R7,%SHIFT_INP
NOP
SLLV  $R7,%ONE
NOP
MOV   $R6,$R0
NOP
JALR  $R1,%CHECK
NOP

// Test for SRAV
.const %SRAV_ANS , 0xC0000000
ADDU  $R5,%ONE
NOP
MOV   $R7,%SHIFT_INP
NOP
SRAV  $R7,%ONE
NOP
MOV   $R6,%SRAV_ANS
NOP
JALR  $R1,%CHECK
NOP


// Test for SRLV
.const %SRLV_ANS , 0x40000000
ADDU  $R5,%ONE
NOP
MOV   $R7,%SHIFT_INP
NOP
SRLV  $R7,%ONE
NOP
MOV   $R6,%SRLV_ANS
NOP
JALR  $R1,%CHECK
NOP

// We can check the correctness of BAR instrution 
// through the output barrier signal.
.const %BARRIER  , 0xFF
BAR %BARRIER
SW    $R13, $R5    // Indicate the test is finished

DONE
// In case the DONE instruction is problematic.
ADDU  $R5,%ONE
SW    $R12, $R5    // Indicate failed test
