#include "harness_start.bash"

##############################################################################
# The four closers                                                           #
##############################################################################
# COMPILER, LINKER, COMPILEOPTS and LINKOPTS are all aimed at whatever
# target was opened last, and that aim is kept in a pointer that
# outlives the target it points at.  SRCDIR, LIBDIR, BUILD_SYSTEMS and
# SUBPROJECTS each go back to the top of the project, which closes the
# open target and opens nothing in its place -- so the four commands
# above still land somewhere, they just land somewhere nobody can read
# from any more.  That's the whole shape of this file: a line that
# looks like it's next to the target it's about and isn't.
#
# All four closers share one loop rather than getting a stanza each.
# Two of them need something real on disk -- BUILD_SYSTEMS wants the
# name of a build system that exists and SUBPROJECTS wants a directory
# with a Configfile in it -- but that's setup, and it can be done once
# up front.  With the setup out of the way the four cases differ by
# exactly one line, and writing them out four times would hide that.
mkdir -p closers/src closers/other closers/otherlib closers/sub/src

cat >closers/src/a.c <<EOF
int main(void) { return 0; }
EOF

cat >closers/sub/Configfile <<EOF
LANGUAGES += c

BINARIES  += subbin
SOURCES   += subbin.c
EOF

cat >closers/sub/src/subbin.c <<EOF
int main(void) { return 0; }
EOF

for closer in "SRCDIR = other" \
              "LIBDIR = otherlib" \
              "BUILD_SYSTEMS += kconfig" \
              "SUBPROJECTS += sub"
do
    # The name of the command on its own, which is what the message
    # calls the thing that did the closing.
    name="$(echo "$closer" | cut -d' ' -f1)"

    cat >closers/Configfile <<EOF
LANGUAGES += c

BINARIES  += a
SOURCES   += a.c
$closer
COMPILER  = clang
EOF

    (cd closers && $PTEST_BINARY $PCONFIGURE_ARGS) > closers.out 2>&1
    cat closers.out

    # Both ends and the line in between.  Naming only the command that
    # went wrong would leave whoever reads this staring at a COMPILER
    # that is sitting right where they put it; the useful half of the
    # message is the line four rows up that moved the target out from
    # under it, so the message quotes that line rather than describing
    # it.
    grep -q "COMPILER lands on the 'a.c' that $name already closed" closers.out
    grep -q "$closer" closers.out

    # ... and it says how to get back to what was meant, in the words
    # of the command that opened the target in the first place.  Here
    # that's the SOURCES, because a SOURCES aims these four at the one
    # file it just named.
    grep -q "open the target again with the SOURCES it belongs to" closers.out

    # A warning and nothing more: pconfigure kept going and wrote a
    # Makefile, which is the compatibility contract every one of these
    # is written to.
    test -f closers/Makefile
done

# The same mistake one line earlier, where what gets closed is the
# BINARIES itself rather than a SOURCES under it.  The message follows
# the target rather than guessing, so it names 'a' and tells whoever
# reads it to open a BINARIES.
#
# This Configfile is wrong in more than one way and says so more than
# once -- a target closed before its SOURCES is also a SOURCES with
# nothing above it and a binary with nothing to build, and those are
# the same mistake seen from two other angles.  Only the first is this
# file's business.
mkdir -p binary/other

cat >binary/other/a.c <<EOF
int main(void) { return 0; }
EOF

cat >binary/Configfile <<EOF
LANGUAGES   += c

BINARIES    += a
SRCDIR       = other
COMPILEOPTS += -DLATE
SOURCES     += a.c
EOF

(cd binary && $PTEST_BINARY $PCONFIGURE_ARGS) > binary.out 2>&1
cat binary.out
grep -q "COMPILEOPTS lands on the 'a' that SRCDIR already closed" binary.out
grep -q "open the target again with the BINARIES it belongs to" binary.out

##############################################################################
# The other three commands                                                   #
##############################################################################
# LINKER, COMPILEOPTS and LINKOPTS reach the closed target through the
# same pointer COMPILER does, so one closer is enough to show all
# three: what's being checked is that every command that writes
# through that pointer asks about it first, not that SRCDIR is special.
mkdir -p others/src others/other

cat >others/src/a.c <<EOF
int main(void) { return 0; }
EOF

for cmd in "LINKER = ld" "COMPILEOPTS += -g" "LINKOPTS += -lm"
do
    name="$(echo "$cmd" | cut -d' ' -f1)"

    cat >others/Configfile <<EOF
LANGUAGES += c

BINARIES  += a
SOURCES   += a.c
SRCDIR     = other
$cmd
EOF

    (cd others && $PTEST_BINARY $PCONFIGURE_ARGS) > others.out 2>&1
    cat others.out
    grep -q "$name lands on the 'a.c' that SRCDIR already closed" others.out
done

# The LINKOPTS above is worth one more look, because there are two
# warnings it could have got and only one of them is right.  A
# LINKOPTS that lands on a source file is the next section's warning,
# but that one asks whether a source context is open, and by the time
# this line is read the SRCDIR has closed it -- the file is stale, not
# open.  Saying both would be saying the same thing twice in two
# voices.
if grep -q "written after a SOURCES" others.out
then
    exit 1
fi

##############################################################################
# Promotion                                                                  #
##############################################################################
# A project that would rather be told loudly says so once at the top,
# and the same line that warned above stops the build instead.
mkdir -p strict/src strict/other

cat >strict/src/a.c <<EOF
int main(void) { return 0; }
EOF

cat >strict/Configfile <<EOF
STRICT     = v0.13

LANGUAGES += c

BINARIES  += a
SOURCES   += a.c
SRCDIR     = other
COMPILER   = clang
EOF

if (cd strict && $PTEST_BINARY $PCONFIGURE_ARGS) > strict.out 2>&1
then
    exit 1
fi
cat strict.out

# The same words with a different first one, so a project that turns
# STRICT on doesn't have to learn a second vocabulary to read what it
# already saw as a warning.
grep -q "error: COMPILER lands on the 'a.c' that SRCDIR already closed" strict.out
if grep -q "warning:" strict.out
then
    exit 1
fi

# ... and it says which line it was that asked for this, since the
# STRICT is usually somewhere the person reading the error isn't
# looking.
grep -q "'STRICT = v0.13' is what makes this an error" strict.out

# Nothing was written.  A Makefile built out of a Configfile that was
# refused is a Makefile that builds the thing that was refused.
test ! -e strict/Makefile

##############################################################################
# The negatives                                                              #
##############################################################################
# The half of this that matters.  Every one of the arrangements below
# is a place where the target the pointer holds isn't the top of the
# stack, and every one of them is correct -- a check that looked at
# the stack instead of at what was popped would warn about all of
# them, and a warning about ordinary Configfiles is worse than no
# warning at all.

# A LANGUAGES opts target, which is the subtlest thing in this file.
# "LANGUAGES += c" aims these commands at the C language rather than
# at a target, and a language isn't a context: it's never pushed and
# so it's never popped, and no SRCDIR can close it.  The COMPILEOPTS
# below still means what it has always meant -- every C file in this
# project, including the ones found under the new SRCDIR -- which is
# why the SRCDIR sitting between the two lines isn't a mistake and
# mustn't be reported as one.
mkdir -p lang/elsewhere

cat >lang/elsewhere/a.c <<EOF
int main(void) { return 0; }
EOF

cat >lang/Configfile <<EOF
LANGUAGES   += c
SRCDIR       = elsewhere
COMPILEOPTS += -DLANGWIDE

BINARIES    += a
SOURCES     += a.c
EOF

(cd lang && $PTEST_BINARY $PCONFIGURE_ARGS) > lang.out 2>&1
cat lang.out
if grep -q "warning:" lang.out
then
    exit 1
fi

# And the option really did reach the file that was found under the
# new SRCDIR, which is the fact the silence is standing for: the
# language outlived the directory change, so the two lines mean one
# thing together.
cat lang/Makefile
grep -q -- "-DLANGWIDE .*-c elsewhere/a.c" lang/Makefile

# A GENERATE, which points these commands at the target it just
# opened and then pushes a source context on top of it on purpose --
# the source being the generator that produces the target.  So the
# pointer isn't the top of the stack here either, and nothing was
# closed to make that true.
mkdir -p generate/src

cat >generate/src/gen.h.proc <<'EOF'
#!/bin/bash
if [[ "$1" == "--deps" ]]
then
    exit 0
fi
if [[ "$1" == "--generate" ]]
then
    echo "#define GEN 1"
    exit 0
fi
exit 1
EOF
chmod +x generate/src/gen.h.proc

cat >generate/src/a.c <<EOF
int main(void) { return 0; }
EOF

cat >generate/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += h

GENERATE    += gen.h
COMPILEOPTS += -DGENERATED

BINARIES    += a
SOURCES     += a.c
EOF

(cd generate && $PTEST_BINARY $PCONFIGURE_ARGS) > generate.out 2>&1
cat generate.out
if grep -q "warning:" generate.out
then
    exit 1
fi

# The two spellings that make up most of every Configfile anybody has
# written: options on the target, and options on one file of it.
# Neither closes anything, so neither has anything to say.
mkdir -p plain/src

cat >plain/src/a.c <<EOF
int main(void) { return 0; }
EOF

cat >plain/Configfile <<EOF
LANGUAGES   += c

BINARIES    += a
COMPILEOPTS += -DUNDER_BINARIES
SOURCES     += a.c
COMPILEOPTS += -DUNDER_SOURCES
EOF

(cd plain && $PTEST_BINARY $PCONFIGURE_ARGS) > plain.out 2>&1
cat plain.out
if grep -q "warning:" plain.out
then
    exit 1
fi

# A COMPILER with nothing above it at all is a different complaint and
# has been one for as long as there's been a COMPILER: there's no
# stale target here, there's no target.  This is the one arrangement
# that could plausibly have been folded into the new warning, and
# folding it in would have turned an error somebody relies on into
# something that keeps going.
mkdir -p none

cat >none/Configfile <<EOF
COMPILER = clang
EOF

if (cd none && $PTEST_BINARY $PCONFIGURE_ARGS) > none.out 2>&1
then
    exit 1
fi
cat none.out
grep -q "COMPILER needs an \*OPTS target" none.out
if grep -q "warning:" none.out
then
    exit 1
fi
if grep -q "already closed" none.out
then
    exit 1
fi

##############################################################################
# LINKOPTS on a source                                                       #
##############################################################################
# A source file is compiled and never linked, so a link option that
# landed on one is read by nobody: the languages ask the target for
# its link options, and the target is the binary.  Nothing was closed
# here and nothing is stale -- the pointer is aimed exactly where the
# Configfile aimed it, and where it was aimed is the problem.
mkdir -p source/src

cat >source/src/a.c <<EOF
  #include <math.h>
int main(void) { return (int)sqrt(4.0) - 2; }
EOF

cat >source/Configfile <<EOF
LANGUAGES += c

BINARIES  += a
SOURCES   += a.c
LINKOPTS  += -lm
EOF

(cd source && $PTEST_BINARY $PCONFIGURE_ARGS) > source.out 2>&1
cat source.out
grep -q "LINKOPTS written after a SOURCES lands on that one file" source.out
grep -q "move it above the SOURCES" source.out

# The assertion the warning is standing in for.  Without this the
# warning is just an opinion about where a line looks best; with it,
# the link line really is missing the library the Configfile asked
# for, and the build that fails at link time an hour from now has its
# reason written down here.
cat source/Makefile
if grep -q -- "-lm" source/Makefile
then
    exit 1
fi

# Written one line higher it lands on the binary, which is the thing
# that gets linked.  No warning, and the library is on the link line
# -- the two halves have to be shown together, since a warning that
# fires on the wrong spelling but nothing on the right one would be
# just as true of a warning that always fires.
mkdir -p target/src

cat >target/src/a.c <<EOF
  #include <math.h>
int main(void) { return (int)sqrt(4.0) - 2; }
EOF

cat >target/Configfile <<EOF
LANGUAGES += c

BINARIES  += a
LINKOPTS  += -lm
SOURCES   += a.c
EOF

(cd target && $PTEST_BINARY $PCONFIGURE_ARGS) > target.out 2>&1
cat target.out
if grep -q "warning:" target.out
then
    exit 1
fi

cat target/Makefile
grep -q -- "-oobj/bin/a/.*-lm" target/Makefile

exit 0
