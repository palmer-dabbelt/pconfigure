unset CC
SWIGFLAGS=()
SWIGINPUTS=()
CFLAGS=()
CINPUTS=()
unset obj_output
unset swig_output
unset target
while [[ "$1" != "" ]]
do
    case "$1" in
    --cc=*)  CC="$(echo "$1" | sed 's/^--cc=//')";;
    -I*) CFLAGS+=("$1") SWIGFLAGS+=("$1");;
    -D*) CFLAGS+=("$1");;
    -f*) CFLAGS+=("$1");;
    -o) obj_output="$2"; swig_output="$2.swig.c"; shift;;
    *.i) SWIGINPUTS+=("$1") SWIGFLAGS+=("-I$(dirname "$1")") CFLAGS+=("-I$(dirname "$1")");;
    *.c++) CINPUTS+=("$1");;
    -c) CFLAGS+=("$1") ;;
    -python) target="$1";;
    *) echo "Unknown argument $1" >&2; exit 1;;
    esac
    shift
done

if [[ "${SWIGINPUTS[*]}" != "" ]]
then
  swig $target -o "$swig_output" ${SWIGFLAGS[*]} ${SWIGINPUTS[*]}
  CINPUTS+=("$swig_output")
fi

$CC -o "$obj_output" ${CFLAGS[*]} ${CINPUTS[*]}
