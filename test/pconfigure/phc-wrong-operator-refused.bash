#include "harness_start.bash"

# Every command that sets one thing takes '=', and writing '+=' for one
# of them is refused with the line and the right spelling.  PHC used to
# be the exception: it never asked which operator it was given, so
# "PHC += tool" was quietly read as "PHC = tool".  A Configfile that
# reads like it adds to a list of header compilers would replace the
# one there is, and nothing said so.
mkdir -p src
echo 'int api(void);' > src/api.h

# The phc that comes with this pconfigure, so that the only thing wrong
# with the line is its operator.
phc="$(dirname "$PTEST_BINARY")/phc"
test -x "$phc"

cat >Configfile <<END
LANGUAGES += c
LANGUAGES += h
PHC       += $phc
HEADERS   += api.h
SOURCES   += api.h
END

if $PTEST_BINARY $PCONFIGURE_ARGS >pluseq.out 2>&1
then
    cat pluseq.out
    exit 1
fi
cat pluseq.out
test ! -e Makefile
grep -q "Configfile:3" pluseq.out
grep -q "Command PHC only supports '='" pluseq.out
grep -qF "write 'PHC = $phc'" pluseq.out

# The same line spelled right is accepted, so it was the operator that
# was refused and not the tool it names.
sed -i 's@^PHC       += @PHC        = @' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
test -e Makefile
