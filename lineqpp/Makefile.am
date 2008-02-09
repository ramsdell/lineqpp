SUBDIRS = lua
bin_PROGRAMS = lineqpp
noinst_PROGRAMS = bin2c
check_SCRIPTS = lineqppchk

AM_YFLAGS = -d
AM_CFLAGS = -I$(srcdir)/lua

lineqpp_SOURCES = parser.y parser.h scanner.l scanner.h solver.c	\
solver.h lineqpp.c lineqpp.h

BUILT_SOURCES = parser.h lineqpp.h

lineqpp_DEPENDENCIES = lua/liblua.a
lineqpp_LDADD = lua/liblua.a @LEXLIB@ -lm

bin2c_SOURCES = bin2c.c

lineqpp.h:	bin2c$(EXEEXT) $(srcdir)/lineqpp.lua
	./bin2c -o $@ -n lineqpp.lua $(srcdir)/lineqpp.lua

TESTS_ENVIRONMENT = $(SHELL)
TESTS = $(check_SCRIPTS)

CLEANFILES = lineqppchk.out
EXTRA_DIST = lineqppchk.lep lineqppchk.txt
