gcc := gcc -O0

# expandA  mcA implements universal syntax and backquote.  expandA expands backquote.

mcA.o : premacros.h mc.h mcA.c premacros.h
	${gcc} -g mcA.c -c

expandA : mcA.o expandA.c
	${gcc} -g -o expandA mcA.o expandA.c -ldl -lm

#testA

testA.c : expandA testA.mc
	./expandA testA.mc testA.c

testA.o : testA.c
	${gcc} -g testA.c -c

# expandB mcB implements pattern matching ucase in terms of backquote.  expandB expands both ucase and backquote.

mcB.c : expandA mcB.mc
	 ./expandA mcB.mc mcB.c

mcB.o : mcB.c
	${gcc} -g mcB.c -c

expandB.c : expandA expandB.mc
	./expandA expandB.mc expandB.c

expandB : mcB.o expandB.c
	${gcc} -g -o expandB mcA.o mcB.o expandB.c -ldl -lm

#testB

testB.c : expandB testB.mc
	./expandB testB.mc testB.c

testB.o : testB.c
	${gcc} -g testB.c -c

#expandC  expandC expands macro definition (umacro) as well as ucase and backquote.

mcC.c : expandB mcC.mc
	./expandB mcC.mc mcC.c

mcC.o : mcC.c
	${gcc} -g mcC.c -c

expandC.c : expandB expandC.mc
	./expandB expandC.mc expandC.c

expandC : mcC.o expandC.c
	${gcc} -g -o expandC mcA.o mcB.o mcC.o expandC.c -ldl -lm

#testC

testC.c : expandC testC.mc
	./expandC testC.mc testC.c

testC.o : testC.c
	${gcc} -g testC.c -c


#expandD  expandD expands some additional generic macros --- push, dolist and sformat.

mcD.c :  expandC mcD.mc
	./expandC mcD.mc mcD.c

mcD.o : mcD.c
	${gcc} -g mcD.c -c

expandD.c :  expandC expandD.mc
	./expandC expandD.mc expandD.c

expandD : mcD.o expandD.c
	${gcc} -g -o expandD mcA.o mcB.o mcC.o mcD.o expandD.c -ldl -lm

#testD

testD.c : expandD testD.mc
	./expandD testD.mc testD.c

testD.o : testD.c
	${gcc} -g testD.c -c

#mcE defines REPL and NIDE procedures but does not define macros.
#No new expansion executable is needed.

mcE.c :  expandD mcE.mc
	./expandD mcE.mc mcE.c

mcE.o : mcE.c
	${gcc} -g mcE.c -c


#mcF defines install_base_properties macro.  Note the dependence on base_decls.h

mcF.c :  expandD mcF.mc
	/expandD mcF.mc mcF.c

mcF.o : mcF.c
	${gcc} -g mcF.c -c

expandF.c :  expandD expandF.mc
	./expandD expandF.mc expandF.c

expandF : mcF.o expandF.c base_decls.h
	${gcc} -g -o expandF mcA.o mcB.o mcC.o mcD.o mcF.o expandF.c -ldl -lm


#REPL the REPL is simpler than the NIDE for debugging with GDB

REPL.c : REPL.mc expandF
	./expandF REPL.mc REPL.c

REPL : REPL.c
	${gcc} -g -o REPL mcA.o mcB.o mcC.o mcD.o mcE.o mcF.o REPL.c -ldl -lm


#NIDE

NIDE.c : NIDE.mc expandF
	./expandD2 NIDE.mc NIDE.c

NIDE : NIDE.c 
	${gcc} -g -o NIDE mcA.o mcB.o mcC.o mcD.o  NIDE.c mcF.o -ldl -lm


