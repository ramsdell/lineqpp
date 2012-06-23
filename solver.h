/*
  Linear equation solver interface
  Copyright (C) 2008 John D. Ramsdell
*/

#if !defined SOLVER_H
#define SOLVER_H

void solver_init(int debug);
void solver_close(void);

void mk_var(char *var);
void mk_avar(void);
void mk_num(double num);
void mk_app(void);
void mk_med(void);
void mk_add(void);
void mk_sub(void);
void mk_mul(void);
void mk_div(void);
void mk_neg(void);
void mk_pow(void);
void mk_eq(void);
void mk_cmd(void);
void translate(const char* var);

#endif
