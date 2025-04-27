/* parser.h */
#ifndef PARSER_H
#define PARSER_H

#include <stdio.h>

void yyerror(const char *s);
int  yylex(void);
extern FILE *yyin;

void addQuadruple(const char *x, const char *op, const char *y, const char *r);
void displayQuadruple(void);
char* tempVar(void);

#endif
