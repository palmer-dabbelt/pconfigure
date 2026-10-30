#include "harness_start.bash"

# A PHC that names no program fails the header copy pconfigure makes
# while configuring, and the complaint used to be about the copy's
# destination: "check that include is a directory pconfigure can
# write".  The directory is fine.  What's wrong is the tool, and the
# shell has already said "not found" about it, so the advice sent the
# reader to the one thing that isn't the problem.  The complaint
# should name PHC and where it was set -- both when that was a
# Configfile line and when it was "--phc".
mkdir -p src
echo '#define X 1' > src/x.h

cat >Configfile <<'EOF2'
LANGUAGES += h
PHC        = /nonexistent/phc
HEADERS   += x.h
SOURCES   += x.h
EOF2

if $PTEST_BINARY > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "status 127" out
grep -qF "'/nonexistent/phc' was set by PHC at ./Configfile:2" out
grep -qF "make that PHC name a program" out
if grep -q "is a directory" out
then
    exit 1
fi

sed -i.bak '/^PHC/d' Configfile
if $PTEST_BINARY --phc /nonexistent/phc > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "status 127" out
grep -qF "'/nonexistent/phc' was set by PHC at args:1 '--phc" out
grep -qF "make '--phc' name a program" out
if grep -q "is a directory" out
then
    exit 1
fi
