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
BEQZ  $R7,PASS

ADDU  $R7, $R6     // Reconstruct wrong answer
SW    $R11, $R7    // Output wrong answer
SW    $R12, $R5    // Indicate failed test
ADDU  $R11, %ONE
ADDU  $R12, %ONE
JALR  $R0,$R1

PASS:

SW    $R10, $R5    // indicate passed test
JALR  $R0,$R1

// Backward jump test
START0:
BEQZ  $R0,START1

// Start of the test
START:
BEQZ  $R0,START0

START1:

// Test for MOV
MOV   $R5,%ONE
.const %CODE_Test,  0xC0DEC0DE
.const %FAIL_Test,  0xDEADDEAD
.const %PASS_Test,  0xC0FFEEEE
.const %DONE_Test,  0x600DBEEF
MOV   $R10,%PASS_Test
MOV   $R11,%CODE_Test
MOV   $R12,%FAIL_Test
MOV   $R13,%DONE_Test

BEQZ  $R5, WRONG1
SW    $R10,$R5   // indicate passed test
BEQZ  $R0, CONT0

WRONG1:
SW    $R11,$R5  // Output wrong answer
SW    $R12,$R5  // Indicate failed test

CONT0:
// Test for ADDU
.constreg $C5, 0x11111111
.constreg $C6, 0xEEEEEEEF
ADDU  $R5,%ONE      // Update test counter 
MOV   $R7,$C5
ADDU  $R7,$C6
BEQZ  $R7,CONT1
SW    $R11,$R5   // Output wrong answer
SW    $R12,$R5   // Indicate failed test

CONT1:
SW    $R10,$R5   // Indicate passed test

// Test for SUBU
ADDU  $R5,%ONE      // Update test counter 
MOV   $R7,$R0
SUBU  $R7,%ONE
ADDU  $R7,%ONE
BEQZ  $R7,CONT2
SW    $R11,$R5   // Output wrong answer
SW    $R12,$R5   // Indicate failed test

CONT2:
SW    $R10,$R5   // Indicate passed test

// Test for ADDU and SUBU
ADDU  $R5,%ONE      // Update test counter 
MOV   $R7,$R0
SUBU  $R7,%ONE
ADDU  $R7,%ONE
BEQZ  $R7,CONT3
SW    $R11,$R5   // Output wrong answer
SW    $R12,$R5   // Indicate failed test

CONT3:
SW    $R10,$R5   // Indicate passed test

// Test for JALR
ADDU  $R5,%ONE
.const %NEXT     , NEXT
JALR  $R1,%NEXT
SW    $R12, $R5    // Indicate failed test

NEXT:
//Change the return address to the PASSED_JALR line.
ADDU  $R1,%FOUR    
JALR  $R0,$R1
SW    $R12, $R5    // Indicate failed test

PASSED_JALR:
SW    $R10, $R5    // indicate passed test


// Test for SLC
.const %SLC_INP	,	0XAAF00000
.const %SLC_ANS	,	0x55E00001
ADDU	$R5, %ONE
MOV	$R7, %SLC_INP
SLC	$R7, %ONE
MOV	$R6, %SLC_ANS
JALR	$R1, %CHECK



// We can check the correctness of BAR instrution 
// through the output barrier signal.
.const %BARRIER  , 0xFF
BAR %BARRIER
SW    $R13, $R5    // Indicate the test is finished

DONE
// In case the DONE instruction is problematic.
ADDU  $R5,%ONE
SW    $R12, $R5    // Indicate failed test
