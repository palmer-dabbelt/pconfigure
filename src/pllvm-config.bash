# Parses some special command-line options.  Every other word is a
# method, and each one sets its own flag rather than overwriting a
# single "method" variable: that used to keep only the last one, so
# "--cflags --libs" (what a line compiling and linking one source in
# a single step asks for) got the libs alone, with no warning, and the
# compile lost LLVM's include path.
optional="false"
have=""
cflags="false"
libs="false"
while [[ "$1" != "" ]]
do
    if [[ "$1" == "--optional" ]]
    then
	optional="true"
    elif [[ "$1" == "--have" ]]
    then
	shift
	have="$1"
    elif [[ "$1" == "--cflags" ]]
    then
	cflags="true"
    elif [[ "$1" == "--libs" ]]
    then
	libs="true"
    else
	# Refused here, before llvm-config is asked anything, so that a
	# typo next to a good method isn't hidden behind its output.
	echo "Unsupported method $1" >/dev/stderr
	exit 1
    fi
    
    shift
done

# Runs llvm-config with its stderr thrown away only for --optional,
# which asks for a missing LLVM to be no news at all.  Without it LLVM
# is required, and llvm-config's own complaint is the only thing that
# says what was wrong with it: in a Configfile backtick pconfigure
# itself only learns that the command failed.  This is what
# ppkg-config does with pkg-config's stderr.
run_llvm_config() {
    if [[ "$optional" == "true" ]]
    then
        llvm-config "$@" 2> /dev/null
    else
        llvm-config "$@"
    fi
}

# Check if llvm-config even exists.  A missing one gets a message of
# its own rather than the shell's "command not found", which names
# this script's line number and not what to do about it.
if ! command -v llvm-config > /dev/null
then
    if [[ "$optional" == "true" ]]
    then
        exit 0
    fi
    echo "pllvm-config: no llvm-config on the PATH; install LLVM, put its bin directory on the PATH, or pass --optional if the project builds without it" >&2
    exit 1
fi

# Asking for no method at all is refused: the empty answer it would get
# reads just like an LLVM that needs no flags.
if [[ "$cflags" == "false" && "$libs" == "false" ]]
then
    echo "No method given: ask for --cflags, --libs, or both" >/dev/stderr
    exit 1
fi

if ! run_llvm_config --version > /dev/null
then
    if [[ "$optional" == "true" ]]
    then
        exit 0
    fi
    exit 1
fi

# Make llvm-config look a lot like pkg-config, which answers both
# methods when given both, always with the cflags ahead of the libs
# whatever order they were asked in, and answers a repeated one once.
# Each llvm-config is run on its own and its status checked: put
# together as substitutions in one assignment, the status left behind
# is that of the last one, so a "llvm-config --libs core" that failed
# (an LLVM installed with only its shared library has no static
# component libraries for it to name) still came out as a link line
# with only libclang on it and a status of 0, and the failure turned up
# at link time instead.
stdout=""
retval="0"
if [[ "$cflags" == "true" ]]
then
    stdout="$(run_llvm_config --cflags)"
    retval="$?"
fi
if [[ "$libs" == "true" && "$retval" == "0" ]]
then
    if libs_out="$(run_llvm_config --libs core)" && libdir="$(run_llvm_config --libdir)"
    then
        stdout="$stdout $libs_out -lclang -L$libdir -Wl,-R$libdir"
    else
        retval="$?"
    fi
fi

# If --optional is given then don't panic
if [[ "$retval" != "0" ]]
then
    if [[ "$optional" == "true" ]]
    then
	exit 0
    else
	exit $retval
    fi
fi

# Checks for some special options
if [[ "$have" != "" ]]
then
    stdout="$stdout -DHAVE_$have"
fi

# Outputs the results of pkg-config, without the "-DNDEBUG" LLVM was
# built with: that's LLVM's choice, and borrowing it along with the
# include path would switch off the asserts of the project asking.
# It is dropped as a whole word.  Removing it as a substring (which is
# what a sed over the output did) also takes the front off any longer
# define that starts the same way, turning "-DNDEBUG_ASSERTS=1" into
# the bare word "_ASSERTS=1", which the compiler driver reads as an
# input file.  Globbing is off so that a word that looks like a pattern
# is passed along as written.
set -f
out=""
for word in $stdout
do
    if [[ "$word" != "-DNDEBUG" ]]
    then
        out="$out $word"
    fi
done
echo $out
exit 0
