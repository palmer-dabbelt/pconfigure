verbose="false"
quiet="false"
check_make_check="true"
check_dirs=()
while [[ "$1" == --* ]]
do
    if [[ "$1" == "--verbose" ]]
    then
        verbose="true"
    elif [[ "$1" == "--quiet" ]]
    then
        quiet="true"
    elif [[ "$1" == "--no-check-make-check" ]]
    then
        check_make_check="false"
    elif [[ "$1" == "--check-dir" ]]
    then
        # One per project: a build with subprojects has its test
        # results spread across all of them.
        shift
        check_dirs+=("$1")
    else
        break
    fi
    shift
done

if [[ "${#check_dirs[@]}" == "0" ]]
then
    # A build with subprojects has its test results spread across all
    # of them, and there's nothing in this directory that says where
    # the others are -- so pconfigure writes the list down next to the
    # Makefile it writes at the same time.  A Makefile old enough not
    # to have one, or a tree that was never configured, still has the
    # one directory everybody has.
    if [[ -r obj/check-dirs ]]
    then
        while read -r dir
        do
            if [[ "$dir" != "" ]]
            then
                check_dirs+=("$dir")
            fi
        done <obj/check-dirs
    fi
fi

if [[ "${#check_dirs[@]}" == "0" ]]
then
    check_dirs=(check)
fi

if [[ "$1" == "--check" ]]
then
    make check
    shift
fi

if [[ "$1" == "" ]]
then
    if [[ "$check_make_check" == "true" ]]
    then
        if ! make -q obj/check-all-done 2>/dev/null
        then
            echo "*** WARNING: 'make check' is not up to date ***"
            echo ""
            echo ""
            echo ""
        fi
    fi

    # If there's no test directory anywhere then just give up
    existing=()
    for dir in "${check_dirs[@]}"
    do
        if test -d "$dir"
        then
            existing+=("$dir")
        fi
    done

    if [[ "${#existing[@]}" == "0" ]]
    then
        echo "No tests"
        exit 0
    fi

    # Names a test by the project it belongs to, so that two projects
    # with a test of the same name stay tellable apart.
    label() {
        local dir="$1"
        local file="$2"
        local rest="${file#$dir/}"
        local project="$(dirname "$dir")"

        if [[ "$project" == "." ]]
        then
            echo "$rest"
        else
            echo "$project/$rest"
        fi
    }

    # This subshell is necessary to keep these variables after the
    # loop terminates
    for dir in "${existing[@]}"
    do
        find "$dir" -type f | sort | while read f
        do
            printf '%s\t%s\n' "$dir" "$f"
        done
    done | {
        run="0"
        pass="0"
        fail="0"
        error="0"

        while read dir f
        do
            run=$(expr $run + 1)
            name="$(label "$dir" "$f")"

            # This is a special case that's used for printing the
            # success/failure of test cases
            ret="$(tar -xOf "$f" ptest__return)"
            if [[ "$ret" == "0" ]]
            then
                if [[ "$quiet" != "true" ]]
                then
                    echo -e "  PASS\t$name"
                fi
                pass=$(expr $pass + 1)
            elif [[ "$ret" == "1" ]]
            then
                echo -e "* FAIL\t$name"
                fail=$(expr $fail + 1)

                if [[ "$verbose" == "true" ]]
                then
                    cat "$f"
                fi
            else
                echo -e "! EROR\t$name"
                error=$(expr $error + 1)

                if [[ "$verbose" == "true" ]]
                then
                    tar -xOf "$f" ptest__output
                fi
            fi
        done

        if [[ "$quiet" == "true" ]]
        then
            if [[ "$fail" != "0" ]]
            then
                echo -e "NFAIL\t"$fail
            fi
            if [[ "$error" != "0" ]]
            then
                echo -e "NEROR\t"$error
            fi
        else
            echo ""
            echo -e "NRUN\t"$run
            echo -e "NPASS\t"$pass
            echo -e "NFAIL\t"$fail
            echo -e "NEROR\t"$error
        fi

        if [[ "$fail" != "0" ]]
        then
            exit 1
        fi

        if [[ "$error" != "0" ]]
        then
            exit 2
        fi
    }

    error="$?"

    if [[ "$check_make_check" == "true" ]]
    then
        if ! make -q obj/check-all-done 2>/dev/null
        then
            echo ""
            echo ""
            echo ""
            echo "*** WARNING: 'make check' is not up to date ***"
        fi
    fi

    exit $error
fi

# Parse the commandline arguments
test=""
out=""
bin=""
srcdir=""
checkdir=""
command=""
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
    elif [[ "$1" == "--srcdir" ]]
    then
        srcdir="$2"
        shift
        shift
    elif [[ "$1" == "--checkdir" ]]
    then
        checkdir="$2"
        shift
        shift
    elif [[ "$1" == "--args" ]]
    then
        shift
        break
    else
        echo "Unknown argument: $1"
        exit 1
    fi
done

abs_path() {
    case "$1" in
        /*) echo "$1" ;;
        *)  echo "$(pwd)/$1" ;;
    esac
}

out="$(abs_path "$out")"
test="$(abs_path "$test")"

# A test that isn't testing any one program -- one written under a
# PHONY -- gets handed no "--bin" at all.  Making that absolute would
# turn nothing into the directory ptest was started in, which is a
# path, exists, and is not a program: a test that reached for it would
# get something rather than noticing there was nothing.
if [[ "$bin" != "" ]]
then
    bin="$(abs_path "$bin")"
fi

# What pconfigure writes here is already absolute -- make worked it
# out, since only make knows what directory it was run in.  The guard
# is for a ptest run by hand, which was told nothing and should say
# nothing rather than name whatever directory it started in.
if [[ "$srcdir" != "" ]]
then
    srcdir="$(abs_path "$srcdir")"
fi

# The directory this test's own result lands in, which is where the
# result of every other test of the same target lands too -- so it's
# how one test finds what another one left behind.  Same guard, same
# reason: a ptest run by hand was told nothing and says nothing.
if [[ "$checkdir" != "" ]]
then
    checkdir="$(abs_path "$checkdir")"
fi

# This is the regular path where we actually run a test case
tmpdir=`mktemp -d -t ptest-wrapper.XXXXXXXXXX`
trap "rm -rf $tmpdir" EXIT

export PTEST_BINARY="$bin"
export PTEST_SRCDIR="$srcdir"
export PTEST_CHECKDIR="$checkdir"
export PTEST_TMPDIR="$tmpdir"

"$test" "$@" >&"$tmpdir"/ptest__output
echo "$?" >"$tmpdir"/ptest__return

cd $tmpdir
tar -c * > "$out"

rm -rf $tmpdir
