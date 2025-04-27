compiler: compiler.tab.c lex.yy.c
	gcc -o compiler compiler.tab.c lex.yy.c symbol_table.c -lfl

compiler.tab.c compiler.tab.h: compiler.y
	bison -d compiler.y

lex.yy.c: compiler.l compiler.tab.h
	flex compiler.l

clean:
	rm -f compiler compiler.tab.c compiler.tab.h lex.yy.c