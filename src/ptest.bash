# Parse the commandline arguments
test=""
out=""
bin=""
while [[ "$1" != "" ]]
do
    if [[ "$1" == "--test" ]]
    then
        test="$2"
        shift
        shift
    elif [[ "$1" == "--out" ]]
    then
        out="$2"
        shift
        shift
    elif [[ "$1" == "--bin" ]]
    then
        bin="$2"
        shift
        shift
    elif [[ "$1" == "--check" ]]
    then
        # This is a special case that's used for printing the
        # success/failure of test cases
        ret="$(tar -xOf "$2" ptest__return)"
        if [[ "$ret" == "0" ]]
        then
            echo -e "PASS\t$(echo "$2" | cut -d'/' -f2-)"
        elif [[ "$ret" == "1" ]]
        then
            echo -e "FAIL\t$(echo "$2" | cut -d'/' -f2-)"
        else
            echo -e "ERROR\t$(echo "$2" | cut -d'/' -f2-)"
        fi

        exit 0
    else
        echo "Unknown argument: $1"
        exit 1
    fi
done

out="$(readlink -f "$out")"
bin="$(readlink -f "$bin")"
test="$(readlink -f "$test")"

# This is the regular path where we actually run a test case
tmpdir=`mktemp -d`

export PTEST_BINARY="$bin"
export PTEST_TMPDIR="$tmpdir"

"$test" >"$tmpdir"/ptest__stdout 2>"$tmpdir"/ptest__stderr
echo "$?" >"$tmpdir"/ptest__return

cd $tmpdir
tar -c * > "$out"

rm -rf $tmpdir
