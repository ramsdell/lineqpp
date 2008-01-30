/*
  Process comand line arguments, initialize and then run parser
  Copyright (C) 2008 John D. Ramsdell
*/

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "scanner.h"
#include "solver.h"

extern int yyparse(void);

#ifdef PACKAGE
const char package[] = PACKAGE;
#else
const char *package = (const char *)0;
#endif

#ifdef VERSION
const char version[] = VERSION;
#else
const char version[] = "Version information not available";
#endif

static int 
go(int debug, char *input)
{
  solver_init(debug);
  set_file(input);
  return yyparse();
}

/* Generic filtering main and usage routines. */

static void
print_version(const char *program)
{
  if (package)
    program = package;
  fprintf(stderr, "Package: %s %s\n", program, version);
}

static void
usage(const char *prog)
{
  fprintf(stderr,
	  "Usage: %s [options] [input]\n"
	  "Options:\n"
	  "  -o file -- output to file (default is standard output)\n"
	  "  -d      -- print equation debugging information\n"
	  "  -v      -- print version information\n"
	  "  -h      -- print this message\n",
	  prog);
  print_version(prog);
}

int
main(int argc, char **argv)
{
  extern char *optarg;
  extern int optind;

  char *input = NULL;
  char *output = NULL;
  int debug = 0;

  for (;;) {
    int c = getopt(argc, argv, "o:dvh");
    if (c == -1)
      break;
    switch (c) {
    case 'o':
      output = optarg;
      break;
    case 'd':
      debug = 1;
      break;
    case 'v':
      print_version(argv[0]);
      return 0;
    case 'h':
      usage(argv[0]);
      return 0;
    default:
      usage(argv[0]);
      return 1;
    }
  }

  switch (argc - optind) {
  case 0:			/* Use stdin */
    break;
  case 1:
    input = argv[optind];
    if (!freopen(input, "r", stdin)) {
      perror(input);
      return 1;
    }
    break;
  default:
    fprintf(stderr, "Bad arg count\n");
    usage(argv[0]);
    return 1;
  }

  if (output && !freopen(output, "w", stdout)) {
    perror(output);
    return 1;
  }

  return go(debug, input);
}
