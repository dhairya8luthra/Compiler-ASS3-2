/* symtable.h */
#ifndef SYMTABLE_H
#define SYMTABLE_H

#define SYMTAB_SIZE 100

typedef struct {
    char name[20];
    char type[10];
    int  val;
    int  init;
} Sym;

extern Sym symtab[SYMTAB_SIZE];
extern int symi;

void insertSymbol(const char *name, const char *type);
int  lookupSymbol(const char *name);
int lookupValue(const char *name);
const char* getSymbolType(const char *n);
const char* getExpressionType(const char *expr);
int areTypesCompatible(const char *type1, const char *type2);
void updateSymbol(const char *name, int value);
void printSymbolTable(void);
void insertArraySymbol(const char *n, int size, const char *t);
#endif
