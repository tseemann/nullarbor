# common functions for all the plugins

# https://sipb.mit.edu/doc/safe-shell/
set -eu -o pipefail

# print message to stderr
function msg {
  echo -e "$*" 1>&2
}

# print message to stderr and exit
function err {
  echo "ERROR: $*" 1>&2
  exit 1
}

# expects to be called as: exitOnFailure $? "error message"
function exitOnFailure {
  if [ $1 -ne 0 ]; then
    err "$2 failed to run (errorcode=$1)"
  fi
}

function needVar {
  if [ -z "$$1" ]; then
    err "parameter '$1' was empty"
  fi
}

needVar USER
