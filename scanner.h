/*
  Lexical analyzer interface for the linear equation preprocessor
  Copyright (C) 2008 John D. Ramsdell
*/

#if !defined SCANNER_H
#define SCANNER_H

void set_file(const char *);
int yylex(void);
int yyerror(const char *);

#endif
