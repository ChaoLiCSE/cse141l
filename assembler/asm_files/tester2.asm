
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
ADDU  $R5,%ONE      // Update test counter 			// 1
MOV   $R7,$C5
ADDU  $R7,$C6
BEQZ  $R7,CONT1
SW    $R11,$R5   // Output wrong answer
SW    $R12,$R5   // Indicate failed test

CONT1:
SW    $R10,$R5   // Indicate passed test

// Test for SUBU
ADDU  $R5,%ONE      // Update test counter 			// 2
MOV   $R7,$R0
SUBU  $R7,%ONE
ADDU  $R7,%ONE
BEQZ  $R7,CONT2
SW    $R11,$R5   // Output wrong answer
SW    $R12,$R5   // Indicate failed test

CONT2:
SW    $R10,$R5   // Indicate passed test

// Test for ADDU and SUBU
ADDU  $R5,%ONE      // Update test counter 		// 3
MOV   $R7,$R0
SUBU  $R7,%ONE
ADDU  $R7,%ONE
BEQZ  $R7,CONT3
SW    $R11,$R5   // Output wrong answer
SW    $R12,$R5   // Indicate failed test

CONT3:
SW    $R10,$R5   // Indicate passed test

// Test for JALR
ADDU  $R5,%ONE												// 4
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


// Test for XOR
.const %XOR_VAL1	,	0xAABBCCDD	
.const %XOR_VAL2	,	0xFF998877
.const %XOR_ANS	,	0x552244AA
ADDU	$R5, %ONE											// 5
MOV	$R7, %XOR_VAL1
MOV	$R2, %XOR_VAL2
XOR	$R7, $R2
MOV	$R6, %XOR_ANS
JALR	$R1, %CHECK

// Test 1 for ROR (rotate with constant value)
.const %ROR_VAL	,	0x76543210
.const %ROR_ANS	,	0x65432107
ADDU	$R5, %ONE											// 6
MOV	$R7, %ROR_VAL
ROL	$R7, %FOUR
MOV	$R6, %ROR_ANS
JALR	$R1, %CHECK

// Test 2 for ROR (rotate with register value)
ADDU	$R5, %ONE											// 7
MOV	$R7, %ROR_VAL
MOV	$R2, %FOUR
ROL	$R7, $R2
MOV	$R6, %ROR_ANS
JALR	$R1, %CHECK

// Test 1 for ROL (rotate with contant value)
.const %ROL_INP	,	0XAAF00000
.const %ROL_ANS	,	0x55E00001
ADDU	$R5, %ONE											// 8
MOV	$R7, %ROL_INP
ROL	$R7, %ONE
MOV	$R6, %ROL_ANS
JALR	$R1, %CHECK

// Test 2 for ROL (rotate with register value)
ADDU	$R5, %ONE											// 9
MOV	$R7, %ROL_INP
MOV	$R2, %ONE
ROL	$R7, $R2
MOV	$R6, %ROL_ANS
JALR	$R1, %CHECK

.const %SIGMA_INPUT	,	0x89ABCDEF
.const %BS0_ANS		,	0x22210003
.const %BS1_ANS		,	0xD6316D8A
.const %SS0_ANS		,	0x3D5DCC4C
.const %SS1_ANS		,	0x9F685F13

// Test big-sigma-0
ADDU	$R5, %ONE											// 10
MOV	$R7, %SIGMA_INPUT
MOV	$R6, %BS0_ANS
BS0	$R7, $R7
JALR	$R1, %CHECK

// Test big-sigma-1
ADDU	$R5, %ONE											// 11
MOV	$R7, %SIGMA_INPUT
MOV	$R6, %BS1_ANS
BS1	$R7, $R7
JALR	$R1, %CHECK

// Test small-sigma-0
ADDU	$R5, %ONE											// 12
MOV	$R7, %SIGMA_INPUT
MOV	$R6, %SS0_ANS
SS0	$R7, $R7
JALR	$R1, %CHECK

// Test small-sigma-1
ADDU	$R5, %ONE											// 13
MOV	$R7, %SIGMA_INPUT
MOV	$R6, %SS1_ANS
SS1	$R7, $R7
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