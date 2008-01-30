AC_INIT(LinEqPp, 0.0)

AC_CONFIG_SRCDIR(lineqpp.c)

AM_INIT_AUTOMAKE

AC_PROG_CC

# Add warning when using GGG
if test "X$GCC" = Xyes ; then
  CFLAGS="$CFLAGS -Wall"
fi

AM_PROG_LEX

AC_PROG_YACC

AC_PROG_RANLIB

AC_PROG_INSTALL

AC_CONFIG_FILES([Makefile lua/Makefile])

AC_OUTPUT
