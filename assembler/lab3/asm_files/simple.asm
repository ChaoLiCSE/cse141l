.kernel tester

.text

beqz $r0, gogo
nah:
beqz $r0, stfu

gogo:
beqz $r0, nah

stfu:
or $r0, $r2
