%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtable.h"

static char *while_start = NULL, *while_exit = NULL;
static char *for_var_name = NULL, *for_inc_val = NULL, *for_head = NULL, *for_exit = NULL, *for_bound = NULL, *for_inc_temp = NULL;
static int for_is_inc = 0;
static char *elseLab = NULL, *endLab = NULL;
static int in_bound = 0;

int qind = 0;
#define OP_SZ 8
#define A1_SZ 40
#define A2_SZ 40
#define RES_SZ 40

#define MAX_TEMP_VARS 100
struct {
    char name[20];
    int value;
    int initialized;
} temp_vars[MAX_TEMP_VARS];

struct quadruple {
    char op[OP_SZ], a1[A1_SZ], a2[A2_SZ], res[RES_SZ];
} quad[200];

int temp_count = 0;

void addQuadruple(const char *x, const char *o, const char *y, const char *r){
    if (qind >= 200) { fprintf(stderr, "Too many quadruples!\n"); exit(1); }
    strncpy(quad[qind].op,  o, OP_SZ-1);   quad[qind].op[OP_SZ-1]=0;
    strncpy(quad[qind].a1,  x, A1_SZ-1);   quad[qind].a1[A1_SZ-1]=0;
    strncpy(quad[qind].a2,  y, A2_SZ-1);   quad[qind].a2[A2_SZ-1]=0;
    strncpy(quad[qind].res, r, RES_SZ-1);  quad[qind].res[RES_SZ-1]=0;
    qind++;
}

int tempCount = 1, condCount = 1, lblCount = 1;
char* tempVar() { char buf[20]; sprintf(buf, "t%d", tempCount++); return strdup(buf); }
char* condVar() { char buf[20]; sprintf(buf, "t_cond%d", condCount++); return strdup(buf); }
char* newLabel(){ char buf[20]; sprintf(buf, "L%d", lblCount++); return strdup(buf); }

void displayQuadruple(){
    printf("\n--- Three Address Code ---\n");
    int lastWasLabel = 0;
    for(int i=0;i<qind;i++){
        char *op=quad[i].op, *a1=quad[i].a1, *a2=quad[i].a2, *r=quad[i].res;
        if (!strcmp(op,"label")) {
            if (i != 0) printf("\n");
            printf("%s:\n", r);
            lastWasLabel = 1;
            continue;
        }
        if (lastWasLabel) { printf("\n"); lastWasLabel = 0; }
        printf("  ");
        if (!strcmp(op,"iffalse"))
            printf("if %s := 0 goto %s\n", a1, r);
        else if (!strcmp(op,"iftrue"))
            printf("if %s == 1 goto %s\n", a1, r);
        else if (!strcmp(op,"goto"))
            printf("goto %s\n", r);
        else if (!strcmp(op,"print")){
            if (a2[0] != '\0')
                printf("print %s, %s\n", a2, r);
            else
                printf("print %s\n", a1);
        }
        else if (!strcmp(op,"scan"))
            if (r[0] != '\0')
                printf("scan %s, %s\n", a2, r);
            else
                printf("scan %s\n", a2);
        else if (!strcmp(op,""))
            printf("%s := %s\n", r, a1);
        else
            printf("%s := %s %s %s\n", r, a1, op, a2);
    }
    printf("\n");
}

int isdigitt(char c){
    return (c >='0' && c<='9');
}

int isTempVar(const char *str) {
    if (!str || str[0] == '\0') return 0;
    return (str[0] == 't' && (str[1] == '_' || isdigitt(str[1])));
}

int findTempVar(const char *name) {
    for (int i = 0; i < temp_count; i++) {
        if (!strcmp(temp_vars[i].name, name)) {
            return i;
        }
    }
    if (temp_count >= MAX_TEMP_VARS) {
        fprintf(stderr, "Too many temporary variables!\n");
        exit(1);
    }
    strncpy(temp_vars[temp_count].name, name, 19);
    temp_vars[temp_count].name[19] = '\0';
    temp_vars[temp_count].value = 0;
    temp_vars[temp_count].initialized = 0;
    return temp_count++;
}

void updateTempVar(const char *name, int value) {
    int idx = findTempVar(name);
    temp_vars[idx].value = value;
    temp_vars[idx].initialized = 1;
}

int getTempVarValue(const char *name) {
    int idx = findTempVar(name);
    if (!temp_vars[idx].initialized) {
        fprintf(stderr, "Warning: Uninitialized temporary variable %s\n", name);
        return 0;
    }
    return temp_vars[idx].value;
}

static char *makeBinary(const char *l, const char *op, const char *r)
{
    size_t L = strlen(l) + strlen(op) + strlen(r) + 3; /* 2 spaces + NUL */
    char *buf = (char *)malloc(L);
    sprintf(buf, "%s %s %s", l, op, r);
    return buf;
}

static char *intToStr(int v)
{
    char tmp[32];
    sprintf(tmp, "%d", v);
    return strdup(tmp);
}

static const char *ltrim(const char *s)
{
    while (*s == ' ') ++s;
    return s;
}


int isLiteral(const char *str) {
    return str && str[0] == '(' && strchr(str, ',') != NULL;
}

/* returns 1 if it really split, 0 otherwise */
static int splitBinary(const char *text,
                       char *lhs, char *op, char *rhs)
{
    /* we rely on makeBinary():  exactly one space between tokens */
    const char *sp1 = strchr(text, ' ');
    if (!sp1) return 0;
    const char *sp2 = strchr(sp1 + 1, ' ');
    if (!sp2) return 0;

    size_t L1 = sp1 - text;
    size_t L2 = sp2 - sp1 - 1;
    strcpy(lhs, text);
    lhs[L1] = '\0';
    strncpy(op, sp1 + 1, L2);
    op[L2] = '\0';
    strcpy(rhs, sp2 + 1);
    return 1;
}


int parseLiteral(const char *lit) {
    if (!lit || !isLiteral(lit)) return 0;
    char valstr[32], basestr[8];
    int i = 0;
    const char *p = lit + 1;
    while (*p && *p != ',') valstr[i++] = *p++;
    valstr[i] = '\0';
    while (*p && (*p == ',' || *p == ' ')) ++p;
    i = 0;
    while (*p && *p != ')') basestr[i++] = *p++;
    basestr[i] = '\0';
    int base = atoi(basestr);
    if (base < 2 || base > 36) base = 10;
    return (int)strtol(valstr, NULL, base);
}

int getOperandValue(const char *operand)
{
    if (!operand || !*operand) return 0;

    /* 1. literal like "(20, 10)"  */
    if (isLiteral(operand)) return parseLiteral(operand);

    /* 2. plain decimal number     */
    if (isdigitt((unsigned char)operand[0]) ||
        (operand[0] == '-' && isdigitt((unsigned char)operand[1])))
        return atoi(operand);

    /* 3. temp var or normal var   */
    if (isTempVar(operand))       return getTempVarValue(operand);
    if (lookupSymbol(operand) >= 0) return lookupValue(operand);

    /* 4. maybe it's  "<expr> <op> <expr>"  */
    {
        char lhs[128], op[8], rhs[128];
        if (splitBinary(operand, lhs, op, rhs))
        {
            int v1 = getOperandValue(ltrim(lhs));
            int v2 = getOperandValue(ltrim(rhs));

            if      (!strcmp(op, "+"))  return v1 + v2;
            else if (!strcmp(op, "-"))  return v1 - v2;
            else if (!strcmp(op, "*"))  return v1 * v2;
            else if (!strcmp(op, "/"))  { if (v2==0){fprintf(stderr,"div0\n");exit(1);} return v1 / v2; }
            else if (!strcmp(op, "%"))  { if (v2==0){fprintf(stderr,"mod0\n");exit(1);} return v1 % v2; }
            else if (!strcmp(op, ">"))  return v1 >  v2;
            else if (!strcmp(op, "<"))  return v1 <  v2;
            else if (!strcmp(op, ">=")) return v1 >= v2;
            else if (!strcmp(op, "<=")) return v1 <= v2;
            else if (!strcmp(op, "==")) return v1 == v2;
            else if (!strcmp(op, "!=")) return v1 != v2;
        }
    }

    /* 5. fallback – unknown token  */
    fprintf(stderr, "Semantic Error: token '%s' not recognised\n", operand);
    exit(1);
}


void simulateExecution() {
    printf("\n--- Simulating Execution ---\n");
    temp_count = 0;
    int i = 0;
    while (i < qind) {
        struct quadruple q = quad[i];
        printf("Executing: ");
        if (!strcmp(q.op, "label")) {
            printf("Label %s\n", q.res);
        } else if (!strcmp(q.op, "goto")) {
            printf("goto %s\n", q.res);
        } else if (!strcmp(q.op, "iffalse")) {
            printf("if %s == 0 goto %s\n", q.a1, q.res);
        } else if (!strcmp(q.op, "iftrue")) {
            printf("if %s == 1 goto %s\n", q.a1, q.res);
        } else if (!strcmp(q.op, "print")) {
            if (q.a2[0] != '\0')
                printf("print %s, %s\n", q.a2, q.res);
            else
                printf("print %s\n", q.a1);
        } else if (!strcmp(q.op, "scan")) {
            if (q.res[0] != '\0')
                printf("scan %s, %s\n", q.a2, q.res);
            else
                printf("scan %s\n", q.a2);
        } else if (!strcmp(q.op, "")) {
            printf("%s := %s\n", q.res, q.a1);
        } else {
            printf("%s := %s %s %s\n", q.res, q.a1, q.op, q.a2);
        }

        if (!strcmp(q.op, "label")) { i++; continue; }
        if (!strcmp(q.op, "goto")) {
            int found = 0;
            for (int j = 0; j < qind; j++) {
                if (!strcmp(quad[j].op, "label") && !strcmp(quad[j].res, q.res)) {
                    i = j + 1; found = 1; break;
                }
            }
            if (!found) { printf("Error: Label %s not found\n", q.res); exit(1); }
            continue;
        }
        if (!strcmp(q.op, "iffalse") || !strcmp(q.op, "iftrue")) {
            int cond_val = getOperandValue(q.a1);
            printf("  Condition %s = %d\n", q.a1, cond_val);
            int take = ((!strcmp(q.op,"iffalse") && cond_val == 0) || (!strcmp(q.op,"iftrue") && cond_val != 0));
            if (take) {
                int found = 0;
                for (int j = 0; j < qind; j++) {
                    if (!strcmp(quad[j].op, "label") && !strcmp(quad[j].res, q.res)) {
                        printf("  Taking branch to %s\n", q.res);
                        i = j + 1; found = 1; break;
                    }
                }
                if (!found) { printf("Error: Label %s not found\n", q.res); exit(1); }
            } else { printf("  Not taking branch\n"); i++; }
            continue;
        }
        if (!strcmp(q.op, "print")) {
            if (q.a2[0] != '\0')
                printf("  Output: %s %d\n", q.a2, getOperandValue(q.res));
            else
                printf("  Output: %s\n", q.a1);
            i++; continue;
        }
        if (!strcmp(q.op, "scan")) {
            int val; printf("  Input for %s: ", q.a2); scanf("%d", &val);
            if (isTempVar(q.a2)) { updateTempVar(q.a2, val); }
            else { updateSymbol(q.a2, val); }
            i++; continue;
        }

        int val1 = getOperandValue(q.a1);
        printf("  Operand %s = %d\n", q.a1, val1);
        int val2 = 0;
        if (q.a2[0] != '\0' && strcmp(q.op, "uminus") != 0) {
            val2 = getOperandValue(q.a2);
            printf("  Operand %s = %d\n", q.a2, val2);
        }
        int res = 0;
        if (!strcmp(q.op, "")) res = val1;
        else if (!strcmp(q.op, "+")) res = val1 + val2;
        else if (!strcmp(q.op, "-")) res = val1 - val2;
        else if (!strcmp(q.op, "*")) res = val1 * val2;
        else if (!strcmp(q.op, "/")) { if (val2 == 0) { printf("Error: Division by zero\n"); exit(1); } res = val1 / val2; }
        else if (!strcmp(q.op, "%")) { if (val2 == 0) { printf("Error: Modulo by zero\n"); exit(1); } res = val1 % val2; }
        else if (!strcmp(q.op, "==")) res = (val1 == val2);
        else if (!strcmp(q.op, "!=")) res = (val1 != val2);
        else if (!strcmp(q.op, ">")) res = (val1 > val2);
        else if (!strcmp(q.op, "<")) res = (val1 < val2);
        else if (!strcmp(q.op, ">=")) res = (val1 >= val2);
        else if (!strcmp(q.op, "<=")) res = (val1 <= val2);
        else if (!strcmp(q.op, "uminus")) res = -val1;
        else { printf("Unknown operation: %s\n", q.op); exit(1); }

        printf("  Result %s = %d\n", q.res, res);
        if (isTempVar(q.res)) updateTempVar(q.res, res);
        else updateSymbol(q.res, res);
        i++;

        printf("  Symbol table state:\n");
        for (int j = 0; j < symi; j++) if (symtab[j].init) printf("    %s = %d\n", symtab[j].name, symtab[j].val);
        for (int j = 0; j < temp_count; j++) if (temp_vars[j].initialized) printf("    %s = %d\n", temp_vars[j].name, temp_vars[j].value);
        printf("\n");
    }

    printf("\nExecution finished. Final variable states:\n");
    for (int j = 0; j < symi; j++) {
        if (symtab[j].init) printf("%s = %d\n", symtab[j].name, symtab[j].val);
        else printf("%s = (uninitialized)\n", symtab[j].name);
    }
}

extern FILE *yyin;
extern int yylex(void);
void yyerror(const char *s);
%}

%union {
    int    ival;
    struct {int value,base;} iconst;
    char*  sval;
}

%token <sval> BEGIN_KEY END PROGRAM VARDECL INT CHAR
%token <sval> IF ELSE WHILE FOR DO TO INC DEC
%token <sval> PRINT SCAN ASSIGNOP ADDOP SUBOP MULOP DIVOP MODOP RELOP
%token <sval> LPAREN RPAREN LBRACKET RBRACKET COMMA SEMICOLON COLON
%token <sval> ID STRCONST
%token <ival> NUM CHARCONST INDEX
%token <iconst> INTCONST

%type <sval> program var_decl_block varlist var_decl type
%type <sval> stmt_block stmt assign_stmt io_stmt print_stmt scan_stmt print_args scan_fmt scan_args cond_stmt loop_stmt while_stmt for_stmt for_setup block expr bound_expr

%left RELOP
%left ADDOP SUBOP
%left MULOP DIVOP MODOP
%nonassoc UMINUS LOWER_THAN_ELSE

%%

program
  : BEGIN_KEY PROGRAM COLON var_decl_block stmt_block END PROGRAM
    {
      printf("Successfully parsed !!!\n");
    }
  ;

var_decl_block
  : BEGIN_KEY VARDECL COLON varlist END VARDECL
  ;

varlist
  : varlist var_decl
  | var_decl
  ;

var_decl
  : LPAREN ID COMMA type RPAREN SEMICOLON
    { insertSymbol($2, $4); free($2); free($4); }
  | LPAREN ID LBRACKET INTCONST RBRACKET COMMA type RPAREN SEMICOLON
    { insertSymbol($2, $7); free($2); free($7); }
  | LPAREN ID LBRACKET INDEX RBRACKET COMMA type RPAREN SEMICOLON
    { insertSymbol($2, $7); free($2); free($7); }
  ;

type
  : INT  { $$ = strdup("int"); }
  | CHAR { $$ = strdup("char"); }
  ;

stmt_block
  : stmt_block stmt
  | stmt
  ;

stmt
  : assign_stmt
  | io_stmt
  | cond_stmt
  | loop_stmt
  | block
  ;

assign_stmt
  : ID ASSIGNOP expr SEMICOLON
    {
      int idx = lookupSymbol($1);
      if (idx < 0) {
        char errmsg[100];
        sprintf(errmsg, "undeclared variable '%s' in assignment", $1);
        yyerror(errmsg);
      }
      const char *var_type = getSymbolType($1);
      const char *expr_type = getExpressionType($3);
      if (!areTypesCompatible(var_type, expr_type)) {
        char errmsg[200];
        sprintf(errmsg, "type mismatch in assignment to '%s' (%s) from expression of type (%s)", 
                $1, var_type ? var_type : "unknown", expr_type ? expr_type : "unknown");
        yyerror(errmsg);
      }
      addQuadruple($3, "", "", $1);
      updateSymbol($1, atoi($3));
      free($1); free($3);
    }
  ;

io_stmt
  : print_stmt
  | scan_stmt
  ;

print_stmt
  : PRINT LPAREN STRCONST RPAREN SEMICOLON
    { addQuadruple("", "print", $3, ""); free($3); }
  | PRINT LPAREN STRCONST COMMA print_args RPAREN SEMICOLON
    { addQuadruple("", "print", $3, $5); free($3); free($5); }
  ;

print_args
  : expr                 { $$ = $1; }
  | expr COMMA print_args{ free($3); $$ = $1; }
  ;

scan_stmt
  : SCAN LPAREN scan_fmt RPAREN SEMICOLON
    { addQuadruple("", "scan", $3, ""); free($3); }
  | SCAN LPAREN scan_fmt COMMA scan_args RPAREN SEMICOLON
    { addQuadruple("", "scan", $3, $5); free($3); free($5); }
  ;

scan_fmt
  : STRCONST { $$ = $1; }
  ;

scan_args
  : ID { $$ = $1; }
  | ID COMMA scan_args
    {
      size_t L = strlen($1) + 2 + strlen($3) + 1;
      char *buf = malloc(L);
      sprintf(buf, "%s, %s", $1, $3);
      free($1); free($3);
      $$ = buf;
    }
  ;

cond_stmt
  : IF LPAREN expr RPAREN
      {
        char *Tcond = condVar();
        addQuadruple($3, "", "", Tcond);
        elseLab = newLabel();
        endLab  = newLabel();
        addQuadruple(Tcond, "iffalse", "", elseLab);
        free($3);
      }
    block
      {
        addQuadruple("", "goto", "", endLab);
        addQuadruple("", "label", "", elseLab);
      }
    ELSE block SEMICOLON
      {
        addQuadruple("", "label", "", endLab);
      }
  ;

loop_stmt
  : while_stmt
  | for_stmt
  ;

while_stmt
  : WHILE LPAREN expr RPAREN
      {
        struct quadruple rel = quad[--qind];
        while_start = newLabel();
        while_exit  = newLabel();
        addQuadruple("", "label", "", while_start);
        quad[qind++] = rel;
        addQuadruple(rel.res, "iffalse", "", while_exit);
        free($3);
      }
    DO block SEMICOLON
      {
        addQuadruple("", "goto", "", while_start);
        addQuadruple("", "label", "", while_exit);
      }
  ;

for_stmt
  : for_setup DO block SEMICOLON
    {
      char *Tupd = tempVar();
      if (for_is_inc) {
        addQuadruple(for_var_name, "+", for_inc_temp, Tupd);
      } else {
        addQuadruple(for_var_name, "-", for_inc_temp, Tupd);
      }
      addQuadruple(Tupd, "", "", for_var_name);
      addQuadruple("", "goto", "", for_head);
      addQuadruple("", "label", "", for_exit);
      free(for_var_name); free(for_inc_val); free(for_head); free(for_exit); free(for_bound);
    }
  ;

for_setup
  : FOR ID ASSIGNOP expr TO bound_expr INC expr
      {
        addQuadruple($4, "", "", $2);
        updateSymbol($2, atoi($4));
        for_head = newLabel();
        addQuadruple("", "label", "", for_head);
        for_var_name = $2;
        for_is_inc   = 1;
        for_bound   = $6;
        for_inc_val = $8;
        for_exit    = newLabel();
        char *Tbound = tempVar(); addQuadruple($6, "", "", Tbound);
        char *IncOp = tempVar(); for_inc_temp = IncOp; addQuadruple($8, "", "", IncOp);
        char *Tcond = condVar();
        addQuadruple($2, "<=", Tbound, Tcond);
        addQuadruple(Tcond, "iffalse", "", for_exit);
      }
  | FOR ID ASSIGNOP expr TO bound_expr DEC expr
      {
        addQuadruple($4, "", "", $2);
        updateSymbol($2, atoi($4));
        for_head = newLabel(); addQuadruple("", "label", "", for_head);
        for_var_name = $2;
        for_is_inc   = 0;
        for_bound   = $6;
        for_inc_val = $8;
        for_exit    = newLabel();
        char *Tbound = tempVar(); addQuadruple($6, "", "", Tbound);
        char *Tcond = condVar();
        addQuadruple($2, ">=", Tbound, Tcond);
        addQuadruple(Tcond, "iffalse", "", for_exit);
      }
  ;

block
  : BEGIN_KEY stmt_block END
  ;

bound_expr
  : { in_bound = 1; } expr { in_bound = 0; $$ = $2; }
  ;

expr
  : expr ADDOP expr
    {
      if (in_bound) {
        $$ = makeBinary($1, "+", $3);
        free($1); free($3);
      } else {
        char *T = tempVar();
        addQuadruple($1, "+", $3, T);
        $$ = strdup(T);
        free($1); free($3);
      }
    }
  | expr SUBOP expr
    {
      if (in_bound) {
        $$ = makeBinary($1, "-", $3);
        free($1); free($3);
      } else {
        char *T = tempVar();
        addQuadruple($1, "-", $3, T);
        $$ = strdup(T);
        free($1); free($3);
      }
    }
  | expr MULOP expr
    {
      if (in_bound) {
        $$ = makeBinary($1, "*", $3);
        free($1); free($3);
      } else {
        char *T = tempVar();
        addQuadruple($1, "*", $3, T);
        $$ = strdup(T);
        free($1); free($3);
      }
    }
  | expr DIVOP expr
    {
      if (in_bound) {
        $$ = makeBinary($1, "/", $3);
        free($1); free($3);
      } else {
        char *T = tempVar();
        addQuadruple($1, "/", $3, T);
        $$ = strdup(T);
        free($1); free($3);
      }
    }
  | expr MODOP expr
    {
      if (in_bound) {
        $$ = makeBinary($1, "mod", $3);
        free($1); free($3);
      } else {
        char *T = tempVar();
        addQuadruple($1, "mod", $3, T);
        $$ = strdup(T);
        free($1); free($3);
      }
    }
  | expr RELOP expr
    {
      if (in_bound) {
        $$ = makeBinary($1, $2, $3);
        free($1); free($2); free($3);
      } else {
        char *T = condVar();
        addQuadruple($1, $2, $3, T);
        $$ = strdup(T);
        free($1); free($3); free($2);
      }
    }
  | SUBOP expr        %prec UMINUS
    {
      if (in_bound) {
        $$ = makeBinary("uminus","",$2);
      } else {
        char *T = tempVar();
        addQuadruple("uminus","",$2,T);
        $$ = strdup(T);
      }
      free($2);
    }
  | '(' expr ')'
    { $$ = $2; }
  | NUM
    {
      char buf[32];
      sprintf(buf, "%d", $1);
      $$ = strdup(buf);
    }
  | INTCONST
    {
      char buf[32];
      sprintf(buf, "(%d, %d)", $1.value, $1.base);
      $$ = strdup(buf);
    }
  | CHARCONST
    {
      char buf[4];
      sprintf(buf, "'%c'", (char)$1);
      if (in_bound) {
        $$ = strdup(buf);
      } else {
        char *T = tempVar();
        addQuadruple(buf,"","",T);
        $$ = strdup(T);
      }
    }
  | ID
    {
      int idx = lookupSymbol($1);
      if (idx < 0) yyerror("undeclared var");
      if (!symtab[idx].init) yyerror("uninitialized var");
      $$ = strdup($1);
      free($1);
    };

%%

void yyerror(const char *s) {
    fprintf(stderr, "Syntax error: %s\n", s);
    exit(1);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <infile>\n", argv[0]);
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if (!yyin) { perror(argv[1]); return 1; }
    yyparse();
    simulateExecution();
    printSymbolTable();
    fclose(yyin);
    return 0;
}