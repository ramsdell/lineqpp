/*
  C interface into the equation solver in Lua
  Copyright (C) 2008 John D. Ramsdell
*/

#include <stdio.h>
#include <stdlib.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "scanner.h"
#include "lineqpp.h"
#include "solver.h"

static lua_State *L = NULL;

static const char *
pcall_msg(void)
{
  const char *s = lua_tostring(L, -1);
  if (s)
    return s;
  else
    return "no error message available";
}

/* Routines for initialization */

/* Libraries used by lineqpp */
static const luaL_Reg lualibs[] = {
  {"", luaopen_base},
  {LUA_MATHLIBNAME, luaopen_math},
  {LUA_TABLIBNAME, luaopen_table},
  {LUA_STRLIBNAME, luaopen_string},
  {LUA_IOLIBNAME, luaopen_io},	/* For debug output */
  {NULL, NULL}
};

void
solver_init(int debug)
{
  L = luaL_newstate();
  const luaL_Reg *lib = lualibs;
  for (; lib->func; lib++) {	/* Load libraries used by the */
    lua_pushcfunction(L, lib->func); /* Lua lineqpp program. */
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }

  /* Load Lua code */
  if (luaL_loadbuffer(L, (const char*)lineqpp_lua_bytes,
		      sizeof(lineqpp_lua_bytes), lineqpp_lua_source)) {
    fprintf(stderr, "%s\n", pcall_msg());
    lua_close(L);
    exit(1);
  }

  if (lua_pcall(L, 0, 0, 0)) {
    fprintf(stderr, "%s\n", pcall_msg());
    lua_close(L);
    exit(1);
  }

  /* Set verbose to the value of the debug flag */
  lua_pushboolean(L, debug);
  lua_setglobal(L, "verbose");
}

void
solver_close(void)
{
  lua_close(L);
}

static void
err(const char *msg)
{
  yyerror(msg);
  lua_close(L);
  exit(1);
}

static void
pcall(int nargs, int nresults)
{
  if (lua_pcall(L, nargs, nresults, 0))
    err(pcall_msg());
}

/* Parser actions -- expression constructors */

void
mk_var(char *var)
{
  if (!lua_checkstack(L, 2))
    err("Stack cannot grow");
  lua_getfield(L, LUA_GLOBALSINDEX, "variable");
  lua_pushstring(L, var);
  pcall(1, 1);
}

void
mk_avar(void)
{
  if (!lua_checkstack(L, 1))
    err("Stack cannot grow");
  lua_getfield(L, LUA_GLOBALSINDEX, "anonymous_variable");
  pcall(0, 1);
}

void
mk_num(double num)
{
  if (!lua_checkstack(L, 2))
    err("Stack cannot grow");
  lua_getfield(L, LUA_GLOBALSINDEX, "number");
  lua_pushnumber(L, num);
  pcall(1, 1);
}

void binop(const char *op)
{
  if (!lua_checkstack(L, 1))
    err("Stack cannot grow");
  lua_getfield(L, LUA_GLOBALSINDEX, op);
  lua_insert(L, -3);
  pcall(2, 1);
}

void
mk_app(void)
{
  binop("application");
}

void
mk_med(void)
{
  if (!lua_checkstack(L, 1))
    err("Stack cannot grow");
  lua_getfield(L, LUA_GLOBALSINDEX, "mediation");
  lua_insert(L, -4);
  pcall(3, 1);
}

void
mk_add(void)
{
  binop("sum");
}

void
mk_sub(void)
{
  binop("difference");
}

void
mk_mul(void)
{
  binop("product");
}

void
mk_div(void)
{
  binop("quotient");
}

void
mk_neg(void)
{
  if (!lua_checkstack(L, 1))
    err("Stack cannot grow");
  lua_getfield(L, LUA_GLOBALSINDEX, "negation");
  lua_insert(L, -2);
  pcall(1, 1);
}

void
mk_pow(void)
{
  binop("exponentiation");
}

/* Parser actions -- equations and commands */

void
mk_eq(void)
{
  binop("equation");
}

void
mk_cmd(void)
{
  lua_settop(L, 0);
}

/* Substitute a value for a variable when there is a translation. */

void
translate(const char *var)
{
  if (!lua_checkstack(L, 2))
    err("Stack cannot grow");
  lua_getfield(L, LUA_GLOBALSINDEX, "translate");
  lua_pushstring(L, var);
  pcall(1, 1);
  const char *s = lua_tostring(L, -1);
  if (s)
    var = s;
  printf("%s", var);
  lua_pop(L, 1);
}
