%{

/*
  A parser for the linear equations preprocessor
  Copyright (C) 2008 John D. Ramsdell
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "scanner.h"
#include "solver.h"

%}

%token UNUSED ID NUM
%left '-' '+'
%left '*' '/'
%left NEG     /* negation--unary minus */
%right '^'    /* exponentiation */

%start start
%%

start:    opt_cmds		{ solver_close(); }

opt_cmds:
        | cmds opt_semi

opt_semi:
        | ';'

cmds:	  eqns			{ mk_cmd(); }
	| cmds ';' eqns		{ mk_cmd(); }

eqns:	  exp '=' exp		{ mk_eq(); }
	| eqns '=' exp		{ mk_eq(); }

exp:      prim
	| ID prim		{ mk_fun(); }
        | exp '+' exp		{ mk_plus(); }
        | exp '-' exp		{ mk_sub(); }
        | exp '*' exp		{ mk_mul(); }
        | exp '/' exp		{ mk_div(); }
        | '-' exp  %prec NEG	{ mk_neg(); }
        | exp '^' exp		{ mk_exp(); }

prim:	  NUM
	| ID
        | '(' exp ')'
