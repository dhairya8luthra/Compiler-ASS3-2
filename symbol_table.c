/* symbol_table.c */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>  // Added for exit() function
#include "symtable.h"

Sym symtab[SYMTAB_SIZE];
int symi = 0;

void insertSymbol(const char *n, const char *t) {
    if (symi >= SYMTAB_SIZE) {
        fprintf(stderr, "Error: Symbol table full\n");
        exit(1);
    }
    strcpy(symtab[symi].name, n);
    strcpy(symtab[symi].type, t);
    symtab[symi].init = 0;  // Explicitly mark as uninitialized
    symtab[symi].val = 0;   // Initialize value to 0
    symi++;
}

int lookupValue(const char *n) {
    int idx = lookupSymbol(n);
    if (idx >= 0) {
        if (symtab[idx].init) {
            return symtab[idx].val;
        } else {
            fprintf(stderr, "Semantic Error: Variable '%s' used before initialization.\n", n);
            exit(1);  // Exit with error to prevent further issues
        }
    } else {
        fprintf(stderr, "Semantic Error: Variable '%s' not declared.\n", n);
        exit(1);  // Exit with error to prevent further issues
    }
}

/* stub for array declarations (records them like scalars) */
void insertArraySymbol(const char *n, int size, const char *t) {
    /* If you later extend Sym to store size, you can record 'size' here */
    insertSymbol(n, t);
}

int lookupSymbol(const char *n) {
    for (int i = 0; i < symi; i++)
        if (strcmp(symtab[i].name, n) == 0)
            return i;
    return -1;
}

void updateSymbol(const char *n, int v) {
    int idx = lookupSymbol(n);
    if (idx >= 0) {
        symtab[idx].val  = v;
        symtab[idx].init = 1;  // Mark as initialized
    } else {
        fprintf(stderr, "Semantic Error: Cannot assign to undeclared variable '%s'.\n", n);
        exit(1);  // Exit with error to prevent further issues
    }
}

/* Get the type of a variable */
const char* getSymbolType(const char *n) {
    int idx = lookupSymbol(n);
    if (idx >= 0) {
        return symtab[idx].type;
    }
    return NULL;
}

/* Check if a variable is initialized */
int isSymbolInitialized(const char *n) {
    int idx = lookupSymbol(n);
    if (idx >= 0) {
        return symtab[idx].init;
    }
    return 0;  // If not found, consider uninitialized
}

/* Get the type of a literal or expression */
const char* getExpressionType(const char *expr) {
    /* Check if it's a literal integer in decimal */
    if (expr[0] >= '0' && expr[0] <= '9' || (expr[0] == '-' && expr[1] >= '0' && expr[1] <= '9')) {
        return "int";
    }
    
    /* Check if it's a literal in (value, base) format */
    if (expr[0] == '(' && strchr(expr, ',') != NULL) {
        return "int";
    }
    
    /* Check if it's a character literal */
    if (expr[0] == '\'' && strlen(expr) == 3 && expr[2] == '\'') {
        return "char";
    }
    
    /* If it's a variable or temp var, look up its type */
    if (expr[0] == 't' && (expr[1] == '_' || (expr[1] >= '0' && expr[1] <= '9'))) {
        /* For temp vars, assume int for now - could add temp var type tracking */
        return "int";
    }
    
    /* Otherwise look for variable in symbol table */
    return getSymbolType(expr);
}

int areTypesCompatible(const char *type1, const char *type2) {
    if (type1 == NULL || type2 == NULL) {
        return 0; /* Incompatible if either type is unknown */
    }
    
    /* Check exact match only - no implicit conversions */
    if (strcmp(type1, type2) == 0) {
        return 1;
    }
    
    return 0;
}

void printSymbolTable(void) {
    printf("\n--- Symbol Table ---\n");
    printf("Name\tType\tValue\tInit\n");
    for (int i = 0; i < symi; i++) {
        printf("%s\t%s\t%d\t%d\n",
               symtab[i].name,
               symtab[i].type,
               symtab[i].val,
               symtab[i].init);
    }
}

/* Set initialization status for variables involved in scan operations */
void setScannedVariablesInitialized(const char *vars) {
    char *varsCopy = strdup(vars);
    char *token = strtok(varsCopy, ", ");
    
    while (token != NULL) {
        int idx = lookupSymbol(token);
        if (idx >= 0) {
            symtab[idx].init = 1;  // Mark as initialized
        }
        token = strtok(NULL, ", ");
    }
    
    free(varsCopy);
}