/*
  A scanner for the linear equations preprocessor
  Copyright (C) 2008 John D. Ramsdell

  When the scanner is in the INITIAL start condition, it replaces
  references to variables solved by linear equations with their
  values.  VAR#r inserts a VAR's real part, and VAR#i inserts a VAR's
  imaginary part.  When the scanner is in the leq start condition, it
  interprets its input as linear equations to be solved.
*/

%option noyywrap

%{

#include <stdio.h>
#include <stdlib.h>
#include "solver.h"
#include "parser.h"
#include "scanner.h"

/* For error reporting... */

static int lineno = 1;

%}

%x		leq

letter		[A-Za-z]
digit		[0-9]
id		{letter}({letter}|{digit}|_)*
var		{id}#(x|y)
num		{digit}+("."{digit}*)?|"."{digit}+
punct		"+"|"-"|"*"|"/"|"^"|"["|","|"]"|"("|")"|"="|";"

%%
\n		{ lineno++; putchar('\n'); }
{var}		{ translate(yytext); }
^#lineqpp	{ BEGIN(leq); }
.		{ putchar(yytext[0]); }

<leq>\\\n	{ lineno++; putchar('\n'); }
<leq>\n		{ lineno++; putchar('\n'); BEGIN(INITIAL); }
<leq>[ \t\f\r]+	{ /* delete whitespace */ }

<leq>{id}	{ mk_var(yytext); return ID; }

<leq>"?"	{ mk_avar(); return ID; }

<leq>{num}	{ mk_num(atof(yytext)); return NUM; }

<leq>{punct}	{ return yytext[0]; }

<leq>.		{ return UNUSED; }

%%

static const char *filename = "-";

void
set_file(const char *path)
{
  if (path)
    filename = path;
}

int
yyerror(const char *msg)
{
  return fprintf(stderr, "%s:%d: %s at token %s\n",
		 filename, lineno, msg, yytext);
}
