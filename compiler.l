%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "compiler.tab.h"

int lineno = 1;
%}


DIGIT       [0-9]
LETTER      [a-z]
WHITESPACE  [ \t\r]
NEWLINE     \n

%%

"begin"     { return BEGIN_KEY; }
"end"       { return END; }
"program"   { return PROGRAM; }
"VarDecl"   { return VARDECL; }
"int"       { return INT; }
"char"      { return CHAR; }
"if"        { return IF; }
"else"      { return ELSE; }
"while"     { return WHILE; }
"for"       { return FOR; }

"print"     { return PRINT; }
"scan"      { return SCAN; }
"do"        { return DO; }
"to"        { return TO; }
"inc"       { return INC; }
"dec"       { return DEC; }

"("         { return LPAREN; }
")"         { return RPAREN; }
"["         { return LBRACKET; }
"]"         { return RBRACKET; }
";"         { return SEMICOLON; }
":"         { return COLON; }
","         { return COMMA; }

":="        { return ASSIGNOP; }
"+="        { return ASSIGNOP; }
"-="        { return ASSIGNOP; }
"*="        { return ASSIGNOP; }
"/="        { return ASSIGNOP; }
"%="        { return ASSIGNOP; }

"+"         { return ADDOP; }
"-"         { return SUBOP; }
"*"         { return MULOP; }
"/"         { return DIVOP; }
"%"         { return MODOP; }

"="         { yylval.sval = strdup(yytext);return RELOP; }
">"         { yylval.sval = strdup(yytext);return RELOP; }
"<"         { yylval.sval = strdup(yytext);return RELOP; }
">="        { yylval.sval = strdup(yytext);return RELOP; }
"<="        { yylval.sval = strdup(yytext);return RELOP; }
"!="        { yylval.sval = strdup(yytext);return RELOP; }

{LETTER}({LETTER}|{DIGIT}|_)*  {
    
    int underscores = 0;
    for (int i = 0; yytext[i] != '\0'; i++) {
        if (yytext[i] == '_') underscores++;
    }
    if (underscores <= 1) {
        yylval.sval = strdup(yytext);
        return ID;
    } else {
        printf("Syntax error !!!");
        exit(1);
    }
}

\([0-9]+,[ ]*(2|8|10)\)  {
    char value[32], base[4];
    sscanf(yytext, "(%[^,],%[^)])", value, base);

    int valid = 1;
    int base_int = atoi(base);

    for (int i = 0; value[i] != '\0'; i++) {
        if (base_int == 2 && value[i] != '0' && value[i] != '1') valid = 0;
        else if (base_int == 8 && (value[i] < '0' || value[i] > '7')) valid = 0;
        else if (base_int == 10 && (value[i] < '0' || value[i] > '9')) valid = 0;
    }

    if (!valid || (base_int != 2 && base_int != 8 && base_int != 10)) {
        printf("Syntax error\n");
        exit(1);
    }

    yylval.iconst.base = base_int;
    yylval.iconst.value = atoi(value);
    return INTCONST;
}
[0-9]+ return INDEX;

\'([^\'\\]|\\.)\'  {
   
    if (yytext[1] == '\\') {
        switch (yytext[2]) {
            case 'n': yylval.ival = '\n'; break;
            case 't': yylval.ival = '\t'; break;
            case '\\': yylval.ival = '\\'; break;
            case '\'': yylval.ival = '\''; break;
            default: yylval.ival = yytext[2];
        }
    } else {
        yylval.ival = yytext[1];
    }
    return CHARCONST;
}

\"([^\"\\]|\\.)*\"  {
    
    yylval.sval = strdup(yytext);
    return STRCONST;
}

"//".*      { /* Skip single-line comments */ }

"/*"([^*]|\*+[^*/])*\*+"/" { /* Skip multi-line comments */ }

{WHITESPACE}+  { /* Skip whitespace */ }

{NEWLINE}   { lineno++; }

.           { 
    printf("Syntax error !!!\n");
    exit(1);
}



%%

int yywrap() {
    return 1;
}