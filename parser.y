%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Value type */
typedef struct {
    int   type;     /* 0=int, 1=float, 2=string/char */
    int   i;
    double d;
    char *s;
} Value;

/* ================================================
   AST STRUCTURES (full definitions here)
   ================================================ */
typedef struct Expr {
    int kind;       /* 0=int, 1=double, 2=string, 3=ID, 4=binop, 5=compare */
    int op;
    int i;
    double d;
    char *s;
    char *id;
    struct Expr *left;
    struct Expr *right;
} Expr;

typedef struct Statement Statement;

typedef enum {
    ST_DECL, ST_ASSIGN, ST_PRINT,
    ST_IF, ST_WHILE, ST_DO_WHILE, ST_FOR, ST_SWITCH
} StmtKind;

struct Statement {
    StmtKind kind;
    union {
        struct { int type; char *id; Expr *init; } decl;
        struct { char *id; Expr *expr; } assign;
        struct { Expr *expr; } print;
        struct { Expr *cond; Statement *body; Statement *else_body; } ifs;
        struct { Expr *cond; Statement *body; } whiles;
        struct { Statement *body; Expr *cond; } dowhile;
        struct { Statement *init; Expr *cond; Statement *incr; Statement *body; } fors;
    } u;
    Statement *next;
};

Statement *program_root = NULL;

/* ================================================
   SYMBOL TABLE + OUTPUT
   ================================================ */
#define MAX_VARS 256
typedef struct {
    char  *name;
    Value  val;
    int    declared;
    int    used;
} Symbol;

Symbol sym_table[MAX_VARS];
int    sym_count = 0;

int getIndex(const char *name) {
    int i;
    for (i = 0; i < sym_count; i++)
        if (strcmp(sym_table[i].name, name) == 0) return i;
    if (sym_count >= MAX_VARS) { fprintf(stderr, "Symbol table full!\n"); exit(1); }
    sym_table[sym_count].name = strdup(name);
    sym_table[sym_count].val = (Value){0,0,0.0,NULL};
    sym_table[sym_count].declared = 0;
    sym_table[sym_count].used = 0;
    return sym_count++;
}

void sym_set(const char *name, Value v) {
    int idx = getIndex(name);
    sym_table[idx].val = v;
    sym_table[idx].declared = 1;
}

Value sym_get(const char *name) {
    int idx = getIndex(name);
    if (!sym_table[idx].declared)
        fprintf(stderr, "Warning: '%s' used before assignment.\n", name);
    sym_table[idx].used++;
    return sym_table[idx].val;
}

#define MAX_OUTPUT 1024
char *out_buf[MAX_OUTPUT];
int   out_count = 0;

void buffer_print(Value *v) {
    char tmp[512];
    if (v->type == 0) snprintf(tmp, sizeof(tmp), "%d", v->i);
    else if (v->type == 1) snprintf(tmp, sizeof(tmp), "%.6lf", v->d);
    else snprintf(tmp, sizeof(tmp), "%s", v->s ? v->s : "");
    out_buf[out_count++] = strdup(tmp);
}

void print_output() {
    int i;
    printf("\n============================================================\n");
    printf("  OUTPUT\n");
    printf("============================================================\n");
    for (i = 0; i < out_count; i++) {
        printf("  %s\n", out_buf[i]);
        free(out_buf[i]);
    }
    printf("============================================================\n");
}

static double toDouble(Value v) {
    return (v.type == 1) ? v.d : (double)v.i;
}

/* ================================================
   AST CREATION HELPERS (no tokens used)
   ================================================ */
Expr *new_expr(int kind) {
    Expr *e = (Expr*)malloc(sizeof(Expr));
    e->kind = kind; e->op = 0; e->i = 0; e->d = 0.0;
    e->s = NULL; e->id = NULL; e->left = NULL; e->right = NULL;
    return e;
}

Expr *make_int(int v) { Expr *e = new_expr(0); e->i = v; return e; }
Expr *make_double(double v) { Expr *e = new_expr(1); e->d = v; return e; }
Expr *make_string(char *v) { Expr *e = new_expr(2); e->s = strdup(v); return e; }
Expr *make_id(char *v) { Expr *e = new_expr(3); e->id = strdup(v); return e; }
Expr *make_binop(Expr *l, int op, Expr *r) { Expr *e = new_expr(4); e->op = op; e->left = l; e->right = r; return e; }
Expr *make_compare(Expr *l, int op, Expr *r) { Expr *e = new_expr(5); e->op = op; e->left = l; e->right = r; return e; }

Statement *new_stmt(StmtKind k) {
    Statement *s = (Statement*)malloc(sizeof(Statement));
    s->kind = k; s->next = NULL;
    return s;
}

Statement *make_decl(int t, char *id, Expr *init) {
    Statement *s = new_stmt(ST_DECL);
    s->u.decl.type = t; s->u.decl.id = strdup(id); s->u.decl.init = init;
    return s;
}
Statement *make_assign(char *id, Expr *expr) {
    Statement *s = new_stmt(ST_ASSIGN);
    s->u.assign.id = strdup(id); s->u.assign.expr = expr;
    return s;
}
Statement *make_print(Expr *expr) {
    Statement *s = new_stmt(ST_PRINT);
    s->u.print.expr = expr;
    return s;
}
Statement *make_if(Expr *cond, Statement *body, Statement *elseb) {
    Statement *s = new_stmt(ST_IF);
    s->u.ifs.cond = cond; s->u.ifs.body = body; s->u.ifs.else_body = elseb;
    return s;
}
Statement *make_while(Expr *cond, Statement *body) {
    Statement *s = new_stmt(ST_WHILE);
    s->u.whiles.cond = cond; s->u.whiles.body = body;
    return s;
}
Statement *make_do_while(Expr *cond, Statement *body) {
    Statement *s = new_stmt(ST_DO_WHILE);
    s->u.dowhile.cond = cond; s->u.dowhile.body = body;
    return s;
}
Statement *make_for(Statement *init, Expr *cond, Statement *incr, Statement *body) {
    Statement *s = new_stmt(ST_FOR);
    s->u.fors.init = init; s->u.fors.cond = cond;
    s->u.fors.incr = incr; s->u.fors.body = body;
    return s;
}
Statement *make_stub(void) {
    return new_stmt(ST_SWITCH);
}

void yyerror(const char *s);
int yylex();

/* BISON DECLARATIONS */
%}

/* Make Expr/Statement visible to lexer (y.tab.h) */
%code requires {
    typedef struct Expr Expr;
    typedef struct Statement Statement;
}

%start start_rule

%union {
    int ival;
    double dval;
    char *str;
    char *id;
    Expr *expr;
    Statement *stmt;
    int type;
}

%token <ival> INT
%token <dval> DOUBLE
%token <str> STRING
%token <id> ID

%token IF ELSE WHILE DO FOR PRINT SWITCH CASE DEFAULT BREAK
%token GE LE EQ NE GT LT
%token END COLON
%token INT_TYPE FLOAT_TYPE CHAR_TYPE

%left '+' '-'
%left '*' '/'

%type <expr> expr condition
%type <stmt> program statement declaration assignment print_stmt
%type <stmt> if_stmt while_stmt do_while_stmt for_stmt switch_stmt
%type <type> type

%%

start_rule
    : program                   { program_root = $1; }
    ;

program
    : /* empty */               { $$ = NULL; }
    | program statement         { 
        if ($1 == NULL) $$ = $2;
        else {
            Statement *p = $1;
            while (p->next) p = p->next;
            p->next = $2;
            $$ = $1;
        }
      }
    ;

statement
    : declaration END   { $$ = $1; }
    | assignment END    { $$ = $1; }
    | print_stmt END    { $$ = $1; }
    | if_stmt           { $$ = $1; }
    | while_stmt        { $$ = $1; }
    | do_while_stmt     { $$ = $1; }
    | for_stmt          { $$ = $1; }
    | switch_stmt       { $$ = $1; }
    ;

declaration
    : type ID               { $$ = make_decl($1, $2, NULL); free($2); }
    | type ID '=' expr      { $$ = make_decl($1, $2, $4); free($2); }
    ;

type
    : INT_TYPE              { $$ = 0; }
    | FLOAT_TYPE            { $$ = 1; }
    | CHAR_TYPE             { $$ = 2; }
    ;

assignment
    : ID '=' expr           { $$ = make_assign($1, $3); free($1); }
    ;

print_stmt
    : PRINT '(' expr ')'    { $$ = make_print($3); }
    ;

if_stmt
    : IF '(' condition ')' '{' program '}' 
        { $$ = make_if($3, $6, NULL); }
    | IF '(' condition ')' '{' program '}' ELSE '{' program '}' 
        { $$ = make_if($3, $6, $10); }
    ;

while_stmt
    : WHILE '(' condition ')' '{' program '}' 
        { $$ = make_while($3, $6); }
    ;

do_while_stmt
    : DO '{' program '}' WHILE '(' condition ')' END 
        { $$ = make_do_while($7, $3); }
    ;

for_stmt
    : FOR '(' assignment END condition END assignment ')' '{' program '}' 
        { $$ = make_for($3, $5, $7, $10); }
    ;

switch_stmt
    : SWITCH '(' expr ')' '{' case_list '}' 
        { free($3); $$ = make_stub(); }
    ;

case_list
    : case_list case_item
    | /* empty */
    ;

case_item
    : CASE expr COLON program BREAK END   { free($2); }
    | DEFAULT COLON program BREAK END
    ;

condition
    : expr GT expr  { $$ = make_compare($1, GT, $3); }
    | expr LT expr  { $$ = make_compare($1, LT, $3); }
    | expr GE expr  { $$ = make_compare($1, GE, $3); }
    | expr LE expr  { $$ = make_compare($1, LE, $3); }
    | expr EQ expr  { $$ = make_compare($1, EQ, $3); }
    | expr NE expr  { $$ = make_compare($1, NE, $3); }
    ;

expr
    : expr '+' expr     { $$ = make_binop($1, '+', $3); }
    | expr '-' expr     { $$ = make_binop($1, '-', $3); }
    | expr '*' expr     { $$ = make_binop($1, '*', $3); }
    | expr '/' expr     { $$ = make_binop($1, '/', $3); }
    | INT               { $$ = make_int($1); }
    | DOUBLE            { $$ = make_double($1); }
    | STRING            { $$ = make_string($1); free($1); }
    | ID                { $$ = make_id($1); free($1); }
    | '(' expr ')'      { $$ = $2; }
    ;

%%

/* ================================================
   EVALUATORS - moved here so they see the tokens
   ================================================ */
Value eval_expr(Expr *e) {
    Value v = {0, 0, 0.0, NULL};
    if (!e) return v;

    if (e->kind == 0) { v.type = 0; v.i = e->i; }
    else if (e->kind == 1) { v.type = 1; v.d = e->d; }
    else if (e->kind == 2) { v.type = 2; v.s = strdup(e->s); }
    else if (e->kind == 3) {
        v = sym_get(e->id);
        if (v.s) v.s = strdup(v.s);
    }
    else if (e->kind == 4) {
        Value l = eval_expr(e->left);
        Value r = eval_expr(e->right);
        if (e->op == '+') {
            if (l.type == 1 || r.type == 1) { v.type = 1; v.d = toDouble(l) + toDouble(r); }
            else { v.type = 0; v.i = l.i + r.i; }
        } else if (e->op == '-') {
            if (l.type == 1 || r.type == 1) { v.type = 1; v.d = toDouble(l) - toDouble(r); }
            else { v.type = 0; v.i = l.i - r.i; }
        } else if (e->op == '*') {
            if (l.type == 1 || r.type == 1) { v.type = 1; v.d = toDouble(l) * toDouble(r); }
            else { v.type = 0; v.i = l.i * r.i; }
        } else if (e->op == '/') {
            if (l.type == 1 || r.type == 1) {
                v.type = 1; v.d = toDouble(l) / toDouble(r);
            } else {
                v.type = 0; v.i = l.i / r.i;
            }
        }
    }
    return v;
}

int eval_condition(Expr *e) {
    if (e->kind != 5) return 0;
    Value l = eval_expr(e->left);
    Value r = eval_expr(e->right);
    double dl = toDouble(l), dr = toDouble(r);
    if (e->op == GT)   return dl > dr;
    if (e->op == LT)   return dl < dr;
    if (e->op == GE)   return dl >= dr;
    if (e->op == LE)   return dl <= dr;
    if (e->op == EQ)   return dl == dr;
    if (e->op == NE)   return dl != dr;
    return 0;
}

void execute(Statement *s) {
    while (s) {
        if (s->kind == ST_DECL) {
            Value v = {s->u.decl.type, 0, 0.0, NULL};
            if (s->u.decl.init) v = eval_expr(s->u.decl.init);
            sym_set(s->u.decl.id, v);
        }
        else if (s->kind == ST_ASSIGN) {
            Value v = eval_expr(s->u.assign.expr);
            sym_set(s->u.assign.id, v);
        }
        else if (s->kind == ST_PRINT) {
            Value v = eval_expr(s->u.print.expr);
            buffer_print(&v);
        }
        else if (s->kind == ST_IF) {
            if (eval_condition(s->u.ifs.cond))
                execute(s->u.ifs.body);
            else if (s->u.ifs.else_body)
                execute(s->u.ifs.else_body);
        }
        else if (s->kind == ST_WHILE) {
            while (eval_condition(s->u.whiles.cond))
                execute(s->u.whiles.body);
        }
        else if (s->kind == ST_DO_WHILE) {
            do { execute(s->u.dowhile.body); }
            while (eval_condition(s->u.dowhile.cond));
        }
        else if (s->kind == ST_FOR) {
            execute(s->u.fors.init);
            while (eval_condition(s->u.fors.cond)) {
                execute(s->u.fors.body);
                execute(s->u.fors.incr);
            }
        }
        s = s->next;
    }
}

void yyerror(const char *s) { fprintf(stderr, "Syntax Error: %s\n", s); }

int main()
{
    printf("============================================================\n");
    printf("  Compiler project is running \n");
    printf("============================================================\n");
    printf("  Write your code below don't panic.\n");
    printf("  Press Ctrl+Z then Enter when  you are done.\n");
    printf("============================================================\n\n");

    yyparse();
    execute(program_root);
    print_output();

    return 0;
}