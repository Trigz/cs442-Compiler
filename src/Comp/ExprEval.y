%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../SymTab/SymTab.h"
#include "../IOMngr/IOMngr.h"
#include "semantics.h"
#include "codegen.h"

int yylex(); /* The next token function. */
int yyerror(const char *);
void dumpTable();
extern char *yytext;   /* The matched token text.  */
extern int yyleng;      /* The token text length.   */
extern int yyparse();

extern struct SymTab *table;
extern struct SymEntry *entry;

%}

%union {
  int val;
  char * string;
  struct ExprRes * ExprRes;
  struct InstrSeq * InstrSeq;
  struct BExprRes * BExprRes;
}

%type <string> Id
%type <ExprRes> Factor
%type <ExprRes> Term
%type <ExprRes> ETerm
%type <ExprRes> NTerm
%type <ExprRes> Expr
%type <InstrSeq> StmtSeq
%type <InstrSeq> Stmt
%type <ExprRes> BExpr
%type <ExprRes> BHExpr
%type <ExprRes> OExpr
%type <ExprRes> AExpr
%type <InstrSeq> PVarSeq
%type <InstrSeq> RVarSeq
%type <val> IntVal

%token Ident        
%token IntLit   
%token Int
%token Bool
%token Str
%token NOT
%token OR
%token AND
%token True
%token False
%token Write
%token Writeln
%token Writesp
%token Read
%token While
%token IF
%token ELSE
%token EQ   
%token LT
%token LTE
%token GT
%token GTE
%token NE

%%

Prog            :   Declarations StmtSeq                                    {Finish($2); } ;
Declarations    :   Dec Declarations                                        { };
Declarations    :                                                           { };
Dec             :   Int Id ';'                                              {doDeclare($2, T_INT, 1); };
Dec             :   Bool Id ';'                                             {doDeclare($2, T_BOOL, 1); };
Dec             :   Int Id '[' IntVal ']' ';'                               {doDeclare($2, T_INT_ARR, $4);};
Dec             :   Bool Id '[' IntVal ']' ';'                              {doDeclare($2, T_BOOL_ARR, $4);};
StmtSeq         :   Stmt StmtSeq                                            {$$ = AppendSeq($1, $2); };
StmtSeq         :                                                           {$$ = NULL; };
Stmt            :   While '(' AExpr ')' '{' StmtSeq '}'                     {$$ = doWhile($3, $6); };
Stmt            :   IF '(' AExpr ')' '{' StmtSeq '}'                        {$$ = doIf($3, $6);};
Stmt            :   IF '(' AExpr ')' '{' StmtSeq '}' ELSE '{' StmtSeq '}'   {$$ = doIfElse($3, $6, $10);};
Stmt            :   Read '(' RVarSeq ')' ';'                                {$$ = $3;};
Stmt            :   Writesp '(' AExpr ')' ';'                               {$$ = doPrintSp($3);};
Stmt            :   Writeln ';'                                             {$$ = doPrintLn();};
Stmt            :   Write '(' PVarSeq ')' ';'                               {$$ = $3;};
Stmt            :   Id '=' AExpr ';'                                        {$$ = doAssign($1, $3);};
Stmt            :   Id '[' AExpr ']' '=' AExpr ';'                          {$$ = doAssignArr($1, $6, $3);};
RVarSeq         :   Id ',' RVarSeq                                          {$$ = doReadList($1, $3);};
RVarSeq         :   Id                                                      {$$ = doRead($1);};
PVarSeq         :   AExpr ',' PVarSeq                                       {$$ = doPrintList($1, $3);};
PVarSeq         :   AExpr                                                   {$$ = doPrint($1);};
AExpr           :   AExpr AND OExpr                                         {$$ = doBoolOp($1, $3, B_AND); };
AExpr           :   OExpr                                                   {$$ = $1;};
OExpr           :   OExpr OR BHExpr                                         {$$ = doBoolOp($1, $3, B_OR); };
OExpr           :   BHExpr                                                  {$$ = $1;};
BHExpr          :   BHExpr EQ BExpr                                         {$$ = doComp($1, $3, B_EQ);};
BHExpr          :   BHExpr NE BExpr                                         {$$ = doComp($1, $3, B_NE);};
BHExpr          :   BExpr                                                   {$$ = $1;};
BExpr           :   BExpr LT Expr                                           {$$ = doComp($1, $3, B_LT);};
BExpr           :   BExpr LTE Expr                                          {$$ = doComp($1, $3, B_LTE);};
BExpr           :   BExpr GT Expr                                           {$$ = doComp($1, $3, B_GT);};
BExpr           :   BExpr GTE Expr                                          {$$ = doComp($1, $3, B_GTE);};
BExpr           :   Expr                                                    {$$ = $1;};
Expr            :   Expr '+' Term                                           {$$ = doArith($1, $3, '+'); };
Expr            :   Expr '-' Term                                           {$$ = doArith($1, $3, '-'); };
Expr            :   Term                                                    {$$ = $1; };
Term            :   Term '*' ETerm                                          {$$ = doArith($1, $3, '*'); };
Term            :   Term '/' ETerm                                          {$$ = doArith($1, $3, '/'); };
Term            :   Term '%' ETerm                                          {$$ = doArith($1, $3, '%'); };
Term            :   ETerm                                                   {$$ = $1; }
ETerm           :   NTerm '^' ETerm                                         {$$ = doPow($1, $3); };
ETerm           :   NTerm                                                   {$$ = $1; };
NTerm           :   '-' Factor                                              {$$ = doNegate($2); };
NTerm           :   Factor                                                  {$$ = $1; };
Factor          :   IntLit                                                  {$$ = doIntLit(yytext); };
Factor          :   Id                                                      {$$ = doRval($1); };
Factor          :   Id '[' AExpr ']'                                        {$$ = doArrVal($1, $3);};
Factor          :   '(' AExpr ')'                                           {$$ = $2; };
Factor          :   NOT AExpr                                               {$$ = doNot($2);};
Factor          :   True                                                    {$$ = doBoolLit(B_TRUE);};
Factor          :   False                                                   {$$ = doBoolLit(B_FALSE);};
Factor          :   Str                                                     {$$ = doStrLit(yytext);};
Id              :   Ident                                                   {$$ = strdup(yytext); };
IntVal          :   IntLit                                                  {$$ = atoi(yytext); };
 
%%

int yyerror(const char *s)  {
  WriteIndicator(GetCurrentColumn());
  WriteMessage("Illegal Character in YACC");
  return 1;
}
