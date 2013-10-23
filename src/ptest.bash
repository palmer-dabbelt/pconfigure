if [[ "$1" == "" ]]
then
    # If there's no test directory then just give up
    if test ! -d check
    then
        echo "No tests"
        exit 0
    fi

    # This subshell is necessary to keep these variables after the
    # loop terminates
    find check -type f | sort | {
        run="0"
        pass="0"
        fail="0"
        error="0"

        while read f
        do
            run=$(expr $run + 1)
            
            # This is a special case that's used for printing the
            # success/failure of test cases
            ret="$(tar -xOf "$f" ptest__return)"
            if [[ "$ret" == "0" ]]
            then
                echo -e "PASS\t$(echo "$f" | cut -d'/' -f2-)"
                pass=$(expr $pass + 1)
            elif [[ "$ret" == "1" ]]
            then
                echo -e "FAIL\t$(echo "$f" | cut -d'/' -f2-)"
                fail=$(expr $fail + 1)
            else
                echo -e "ERROR\t$(echo "$f" | cut -d'/' -f2-)"
                error=$(expr $error + 1)
            fi
        done

        echo ""
        echo -e "NRUN\t"$run
        echo -e "NPASS\t"$pass
        echo -e "NFAIL\t"$fail
        echo -e "NERROR\t"$error

        if [[ "$fail" != "0" ]]
        then
            exit 1
        fi

        if [[ "$error" != "0" ]]
        then
            exit 2
        fi
    }

    exit $?
fi

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
    else
        echo "Unknown argument: $1"
        exit 1
    fi
done

out="$(pwd)"/"$out"
bin="$(pwd)"/"$bin"
test="$(pwd)"/"$test"

# This is the regular path where we actually run a test case
tmpdir=`mktemp -d -t ptest-wrapper.XXXXXXXXXX`

export PTEST_BINARY="$bin"
export PTEST_TMPDIR="$tmpdir"

"$test" >"$tmpdir"/ptest__stdout 2>"$tmpdir"/ptest__stderr
echo "$?" >"$tmpdir"/ptest__return

cd $tmpdir
tar -c * > "$out"

rm -rf $tmpdir
