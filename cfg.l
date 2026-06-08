%{
/* ================================================
   cfg.l  - Lexer  for RuN Language
   Uses ;   |   int/float/char variables
   ================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Value type - defined here so y.tab.h can see it */
typedef struct {
    int   type;     /* 0=int, 1=float, 2=string/char */
    int   i;
    double d;
    char *s;
} Value;

#include "y.tab.h"

%}

%option noyywrap

%%

"int"       { return INT_TYPE; }
"float"     { return FLOAT_TYPE; }
"char"      { return CHAR_TYPE; }

"if"        { return IF; }
"else"      { return ELSE; }
"while"     { return WHILE; }
"do"        { return DO; }
"for"       { return FOR; }
"print"     { return PRINT; }
"switch"    { return SWITCH; }
"case"      { return CASE; }
"default"   { return DEFAULT; }
"break"     { return BREAK; }

">="        { return GE; }
"<="        { return LE; }
"=="        { return EQ; }
"!="        { return NE; }
">"         { return GT; }
"<"         { return LT; }

";"         { return END; }
":"         { return COLON; }

[ \t\r\n]+  { /* ignore whitespace */ }

[a-zA-Z_][a-zA-Z0-9_]* {
    yylval.id = strdup(yytext);
    return ID;
}

[0-9]+ {
    yylval.ival = atoi(yytext);
    return INT;
}

([0-9]+\.[0-9]*)|(\.[0-9]+) {
    yylval.dval = atof(yytext);
    return DOUBLE;
}

\"[^"\n]*\" {
    yylval.str = strdup(yytext + 1);
    yylval.str[strlen(yylval.str) - 1] = '\0';
    return STRING;
}

"("         { return '('; }
")"         { return ')'; }
"{"         { return '{'; }
"}"         { return '}'; }
"="         { return '='; }
"+"         { return '+'; }
"-"         { return '-'; }
"*"         { return '*'; }
"/"         { return '/'; }

.           {
    fprintf(stderr, "ERROR: Unrecognized character '%s'\n", yytext);
    return yytext[0];
}

%%