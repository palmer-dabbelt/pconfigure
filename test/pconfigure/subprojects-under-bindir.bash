#include "harness_start.bash"

top="$tempdir"

##############################################################################
# A vendored tree checked out under "bin/"                                   #
##############################################################################
# "bin/" is where binaries go, and "make distclean" removes it whole.
# A third-party tool checked out as "bin/tool" -- a submodule of
# scripts, say -- was accepted by SUBPROJECTS because only the object
# directory was asked about, and distclean then removed the checkout
# along with the binaries.  A vendored tree rather than a pconfigure
# one, since the two are read by different code and only one of them
# has a build system to pick.
mkdir -p $top/bin/src $top/bin/bin/tool

cat >$top/bin/Configfile <<'EOF'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += bin/tool

LANGUAGES     += c
BINARIES      += top
SOURCES       += top.c
EOF

cat >$top/bin/bin/tool/Kconfig <<'EOF'
config X
	bool "x"
	default y
EOF

cat >$top/bin/bin/tool/Makefile <<'EOF'
O ?= $(CURDIR)/build
all:
	@mkdir -p $(O)
defconfig:
	@mkdir -p $(O)
	@echo CONFIG_X=y > $(O)/.config
EOF

echo 'int main(void) { return 0; }' > $top/bin/src/top.c

if (cd $top/bin && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/bin.out 2>&1
then
    cat $top/bin.out
    exit 1
fi
cat $top/bin.out
grep -q "^\./Configfile:2 'SUBPROJECTS" $top/bin.out
grep -q "'bin/tool' is inside 'bin', where binaries go" $top/bin.out

# "bin/" can't be moved, so a LIBDIR is no answer and isn't offered.
if grep -q "LIBDIR" $top/bin.out
then
    exit 1
fi
test ! -e $top/bin/Makefile
test -f $top/bin/bin/tool/Kconfig

##############################################################################
# Or under where test results go                                             #
##############################################################################
# The same for "check/", the third directory a target's distclean
# names, reached by a pconfigure subproject this time.
mkdir -p $top/check/src $top/check/check/suite

cat >$top/check/Configfile <<'EOF'
LANGUAGES   += c
BINARIES    += top
SOURCES     += top.c

SUBPROJECTS += check/suite
EOF
echo 'int main(void) { return 0; }' > $top/check/src/top.c
echo "" > $top/check/check/suite/Configfile

if (cd $top/check && $PTEST_BINARY $PCONFIGURE_ARGS) > $top/check.out 2>&1
then
    cat $top/check.out
    exit 1
fi
cat $top/check.out
grep -q "^\./Configfile:5 'SUBPROJECTS" $top/check.out
grep -q "'check/suite' is inside 'check', where test results go" \
    $top/check.out
test ! -e $top/check/Makefile

exit 0
