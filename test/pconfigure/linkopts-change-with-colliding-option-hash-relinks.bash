#include "harness_start.bash"

# A link is named after a hash of its options the way an object is, so
# that a changed LINKOPTS puts the link in a directory it has never
# been in and make has to run it.  Two LINKOPTS that hash alike name
# the same link, and switching between them relinks nothing: the
# program keeps whatever the first one linked in.
#
# Here the two LINKOPTS point the link at two directories, each holding
# a prebuilt archive that answers differently.  The directory names are
# found by asking the C++ library's std::hash, which is what pconfigure
# hashes with, for two whose low 32 bits agree -- a pair that a hash
# folded into 32 bits, as this one used to be, could not tell apart.

cat >find.c++ <<'EOT'
#include <cstdint>
#include <cstdio>
#include <string>
#include <unordered_map>
int main(void)
{
    std::hash<std::string> h;
    std::unordered_map<uint32_t, long> seen;
    /* A pair turns up within a few hundred thousand; the bound is
     * only so a broken std::hash ends the test instead of hanging it. */
    for (long i = 0; i < 10000000; ++i) {
        auto key = static_cast<uint32_t>(h("-Ld" + std::to_string(i)));
        auto found = seen.find(key);
        if (found != seen.end()) {
            printf("%ld %ld\n", found->second, i);
            return 0;
        }
        seen[key] = i;
    }
    return 1;
}
EOT
${CXX:-c++} -O2 -o find find.c++
read first second < <(./find)
test -n "$second"

# Each archive answers with which of the two it is, rather than with
# anything derived from its name, so the two answers can't agree.
answer=1
for n in $first $second
do
    mkdir -p d$n
    echo "int value(void) { return $answer; }" > d$n/value.c
    answer=$((answer + 1))
    ${CC:-cc} -c d$n/value.c -o d$n/value.o
    ${AR:-ar} rcs d$n/libvalue.a d$n/value.o
done

mkdir -p src
cat >src/main.c <<'EOT'
int value(void);
int main(void) { return value(); }
EOT

cat >Configfile <<EOT
LANGUAGES   += c
BINARIES    += app
LINKOPTS    += -Ld$first
LINKOPTS    += -lvalue
SOURCES     += main.c
EOT
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./bin/app
got=$?
set -e
test "$got" = 1

sed -i "s/-Ld$first/-Ld$second/" Configfile
cat Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./bin/app
got=$?
set -e
test "$got" = 2

exit 0
